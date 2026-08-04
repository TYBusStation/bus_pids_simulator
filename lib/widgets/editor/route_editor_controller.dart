import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/bus_route.dart';
import '../../data/bus_station.dart';
import '../../data/route_path.dart';
import '../../data/route_stations.dart';
import '../../utils/formatter_utils.dart';
import '../../utils/static.dart';

class SourceStationGroup {
  final BusStation station;
  final String source;
  final List<String> routeNames;

  SourceStationGroup({
    required this.station,
    required this.source,
    required this.routeNames,
  });

  String get locationKey =>
      "${station.lat.toStringAsFixed(6)}_${station.lon.toStringAsFixed(6)}";
}

enum PathAddMode { none, intermediate, end }

class RouteEditorController extends ChangeNotifier {
  final BusRoute? initialRoute;

  final idCtrl = TextEditingController(),
      nameCtrl = TextEditingController(),
      descCtrl = TextEditingController(),
      depCtrl = TextEditingController(),
      destCtrl = TextEditingController(),
      wktGoCtrl = TextEditingController(),
      wktBackCtrl = TextEditingController(),
      jsonCtrl = TextEditingController();

  List<BusStation> goStations = [], backStations = [];
  List<LatLng> goPath = [], backPath = [];
  bool isEditingGo = true,
      isMapTapMode = false,
      isPathEditing = false,
      isDirty = false,
      isFabMenuExpanded = false,
      isJsonMode = false;

  PathAddMode pathAddMode = PathAddMode.none;
  int? movingStationIndex, movingPathIndex;
  LatLng? previewPoint;
  final MapController mapController = MapController();
  double brightness = 0.6;
  double currentZoom = 16.0;
  Set<String> selectedSources = {'Taoyuan'};
  List<SourceStationGroup> allSourceGroups = [];
  List<SourceStationGroup> nearbySourceGroups = [];
  Timer? mapMoveTimer;

  RouteEditorController({this.initialRoute}) {
    if (initialRoute != null) {
      final r = initialRoute!;
      idCtrl.text = r.id;
      nameCtrl.text = r.name;
      descCtrl.text = r.description;
      depCtrl.text = r.departure;
      destCtrl.text = r.destination;
      wktGoCtrl.text = r.path.go;
      wktBackCtrl.text = r.path.back;
      goStations = List.from(r.stations.go);
      backStations = List.from(r.stations.back);
    }
    syncPaths();
    loadSourceStations(initial: true);
  }

  void markDirty() {
    isDirty = true;
    notifyListeners();
  }

  void syncStationOrders() {
    for (int i = 0; i < goStations.length; i++) {
      goStations[i] = goStations[i].copyWith(order: i + 1);
    }
    for (int i = 0; i < backStations.length; i++) {
      backStations[i] = backStations[i].copyWith(order: i + 1);
    }
  }

  void syncPaths() {
    goPath = Static.wktPrase(wktGoCtrl.text);
    backPath = Static.wktPrase(wktBackCtrl.text);
    notifyListeners();
  }

  String generateWkt(List<LatLng> pts) {
    if (pts.isEmpty) return "";
    final sb = StringBuffer("LINESTRING (");
    for (int i = 0; i < pts.length; i++) {
      sb.write("${pts[i].longitude} ${pts[i].latitude}");
      if (i < pts.length - 1) sb.write(", ");
    }
    sb.write(")");
    return sb.toString();
  }

  void loadSourceStations({bool initial = false}) {
    final Map<String, SourceStationGroup> groupMap = {};
    for (var src in selectedSources) {
      if (src == 'Custom') continue;
      if (Static.routeData[src] == null || Static.routeData[src]!.isEmpty) {
        final cache = Static.getCityCache(src);
        if (cache != null) {
          final dynamic rawData = cache['data'];
          final List<dynamic> data = rawData is String
              ? jsonDecode(rawData)
              : rawData;
          Static.routeData[src] = data
              .map((r) => BusRoute.fromJson(r))
              .toList();
        }
      }
      final routes = Static.routeData[src];
      if (routes == null) continue;
      for (var r in routes) {
        for (var s in [...r.stations.go, ...r.stations.back]) {
          final key =
              "${src}_${s.lat.toStringAsFixed(6)}_${s.lon.toStringAsFixed(6)}";
          if (!groupMap.containsKey(key)) {
            groupMap[key] = SourceStationGroup(
              station: s,
              source: src,
              routeNames: [r.name],
            );
          } else if (!groupMap[key]!.routeNames.contains(r.name)) {
            groupMap[key]!.routeNames.add(r.name);
          }
        }
      }
    }
    for (var group in groupMap.values) {
      group.routeNames.sort((a, b) => FormatterUtils.compareRoutes(a, b));
    }
    allSourceGroups = groupMap.values.toList();
    if (!initial) filterNearbyStations(mapController.camera.center);
    notifyListeners();
  }

  void filterNearbyStations(LatLng center) {
    nearbySourceGroups = allSourceGroups
        .where(
          (g) =>
              Geolocator.distanceBetween(
                center.latitude,
                center.longitude,
                g.station.lat,
                g.station.lon,
              ) <=
              500,
        )
        .toList();
    notifyListeners();
  }

  void onPositionChanged(MapCamera camera) {
    previewPoint = camera.center;
    currentZoom = camera.zoom;
    if (movingStationIndex != null) {
      final list = isEditingGo ? goStations : backStations;
      final s = list[movingStationIndex!];
      list[movingStationIndex!] = s.copyWith(
        lat: camera.center.latitude,
        lon: camera.center.longitude,
      );
    } else if (movingPathIndex != null) {
      final p = List<LatLng>.from(isEditingGo ? goPath : backPath);
      p[movingPathIndex!] = camera.center;
      if (isEditingGo)
        wktGoCtrl.text = generateWkt(p);
      else
        wktBackCtrl.text = generateWkt(p);
      syncPaths();
    }
    mapMoveTimer?.cancel();
    mapMoveTimer = Timer(
      const Duration(milliseconds: 150),
      () => filterNearbyStations(camera.center),
    );
    notifyListeners();
  }

  double distanceToSegment(LatLng p, LatLng a, LatLng b) {
    double x = p.longitude,
        y = p.latitude,
        x1 = a.longitude,
        y1 = a.latitude,
        x2 = b.longitude,
        y2 = b.latitude;
    double dx = x2 - x1, dy = y2 - y1;
    if (dx == 0 && dy == 0) return Geolocator.distanceBetween(y, x, y1, x1);
    double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0);
    return Geolocator.distanceBetween(y, x, y1 + t * dy, x1 + t * dx);
  }

  int getInsertIndex(LatLng point, List<LatLng> path) {
    if (path.length < 2) return -1;
    double minDistance = double.infinity;
    int insertIdx = -1;
    for (int i = 0; i < path.length - 1; i++) {
      double dist = distanceToSegment(point, path[i], path[i + 1]);
      if (dist < minDistance && dist < 15) {
        minDistance = dist;
        insertIdx = i + 1;
      }
    }
    return insertIdx;
  }

  BusRoute prepareRouteData() {
    syncStationOrders();
    return BusRoute(
      id: idCtrl.text.trim(),
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim(),
      departure: depCtrl.text.trim(),
      destination: destCtrl.text.trim(),
      path: RoutePath(go: wktGoCtrl.text, back: wktBackCtrl.text),
      stations: RouteStations(go: goStations, back: backStations),
    );
  }
}
