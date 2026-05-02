import 'package:latlong2/latlong.dart';
import 'package:turf/turf.dart' as turf;

import '../data/bus_station.dart';

class RouteAnalysisResult {
  final bool isOffRoute;
  final double distanceToRoute;
  final BusStation? prevStation;
  final BusStation? nextStation;
  final double? distToPrevStation;
  final double? distToNextStation;
  final double progress;
  final double? bearing;

  RouteAnalysisResult({
    required this.isOffRoute,
    required this.distanceToRoute,
    this.prevStation,
    this.nextStation,
    this.distToPrevStation,
    this.distToNextStation,
    required this.progress,
    this.bearing,
  });
}

class RouteEngine {
  static const double offRouteThreshold = 200.0;

  static RouteAnalysisResult analyze({
    required LatLng currentPos,
    required List<LatLng> routePoints,
    required List<BusStation> stations,
  }) {
    final lineGeom = turf.LineString(
      coordinates: routePoints
          .map((p) => turf.Position(p.longitude, p.latitude))
          .toList(),
    );
    final lineFeature = turf.Feature<turf.LineString>(geometry: lineGeom);
    final pt = turf.Point(
      coordinates: turf.Position(currentPos.longitude, currentPos.latitude),
    );

    final snappedFeature = turf.nearestPointOnLine(lineGeom, pt);
    final double distToRouteMeters =
        (snappedFeature.properties?['dist'] ?? 0) * 1000;
    final bool isOffRoute = distToRouteMeters > offRouteThreshold;
    final double userLocOnLine = snappedFeature.properties?['location'] ?? 0.0;
    final double totalLineDist = turf.length(lineFeature).toDouble();

    double? currentBearing;
    int index = snappedFeature.properties?['index'] ?? 0;
    if (index < routePoints.length - 1) {
      currentBearing = turf
          .bearing(
            turf.Point(
              coordinates: turf.Position(
                routePoints[index].longitude,
                routePoints[index].latitude,
              ),
            ),
            turf.Point(
              coordinates: turf.Position(
                routePoints[index + 1].longitude,
                routePoints[index + 1].latitude,
              ),
            ),
          )
          .toDouble();
    }

    BusStation? prev;
    BusStation? next;
    double? dPrev;
    double? dNext;

    List<Map<String, dynamic>> mapped = [];
    for (var s in stations) {
      final sPt = turf.Point(
        coordinates: turf.Position(s.position.longitude, s.position.latitude),
      );
      final sSnapped = turf.nearestPointOnLine(lineGeom, sPt);
      mapped.add({
        'station': s,
        'location': sSnapped.properties?['location'] ?? 0.0,
      });
    }
    mapped.sort((a, b) => a['location'].compareTo(b['location']));

    for (int i = 0; i < mapped.length; i++) {
      if (userLocOnLine >= mapped[i]['location']) {
        prev = mapped[i]['station'];
        dPrev = (userLocOnLine - mapped[i]['location']).abs() * 1000;
      } else {
        next = mapped[i]['station'];
        dNext = (mapped[i]['location'] - userLocOnLine).abs() * 1000;
        break;
      }
    }

    return RouteAnalysisResult(
      isOffRoute: isOffRoute,
      distanceToRoute: distToRouteMeters,
      prevStation: prev,
      nextStation: next,
      distToPrevStation: dPrev,
      distToNextStation: dNext,
      progress: totalLineDist > 0 ? userLocOnLine / totalLineDist : 0,
      bearing: currentBearing,
    );
  }
}
