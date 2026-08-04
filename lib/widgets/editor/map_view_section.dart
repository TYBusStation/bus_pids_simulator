import 'package:bus_pids_simulator/widgets/editor/route_editor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/bus_station.dart';

class MapViewSection extends StatelessWidget {
  final MapController mapController;
  final List<LatLng> goPath, backPath;
  final bool isEditingGo, isMapTapMode, isPathEditing;
  final int? movingStationIndex, movingPathIndex;
  final LatLng? previewPoint;
  final double brightness;
  final double currentZoom;
  final List<BusStation> nearbySourceStations, goStations, backStations;
  final Function(MapCamera) onPositionChanged;
  final Function(LatLng) onMapTap;
  final Function(LatLng, BusStation) onMarkerTap;
  final Function(int) onPathPointTap;
  final PathAddMode pathAddMode;

  const MapViewSection({
    super.key,
    required this.mapController,
    required this.goPath,
    required this.backPath,
    required this.isEditingGo,
    required this.brightness,
    required this.currentZoom,
    required this.nearbySourceStations,
    required this.goStations,
    required this.backStations,
    required this.onPositionChanged,
    required this.onMapTap,
    required this.onMarkerTap,
    required this.isPathEditing,
    required this.onPathPointTap,
    required this.isMapTapMode,
    required this.pathAddMode,
    this.movingStationIndex,
    this.movingPathIndex,
    this.previewPoint,
  });

  @override
  Widget build(BuildContext context) {
    final activePath = isEditingGo ? goPath : backPath;
    final isMoving = movingStationIndex != null || movingPathIndex != null;

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: const LatLng(24.9892, 121.3135),
            initialZoom: 16,
            onPositionChanged: (p, g) => onPositionChanged(p),
            onTap: (p, point) => onMapTap(point),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.matrix([
                brightness,
                0,
                0,
                0,
                0,
                0,
                brightness,
                0,
                0,
                0,
                0,
                0,
                brightness,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                tileProvider: NetworkTileProvider(),
              ),
            ),
            TileLayer(
              urlTemplate:
                  'https://wmts.nlsc.gov.tw/wmts/EMAP2/default/GoogleMapsCompatible/{z}/{y}/{x}',
              tileProvider: NetworkTileProvider(),
            ),
            PolylineLayer(
              polylines: [
                if (isEditingGo && backPath.isNotEmpty)
                  Polyline(
                    points: backPath,
                    color: Colors.blue.withOpacity(0.5),
                    strokeWidth: 4,
                  ),
                if (!isEditingGo && goPath.isNotEmpty)
                  Polyline(
                    points: goPath,
                    color: Colors.blue.withOpacity(0.5),
                    strokeWidth: 4,
                  ),
                if (activePath.isNotEmpty)
                  Polyline(
                    points: activePath,
                    color: Colors.orange,
                    strokeWidth: 6,
                  ),
                if (isPathEditing &&
                    !isMoving &&
                    pathAddMode == PathAddMode.end &&
                    activePath.isNotEmpty &&
                    previewPoint != null)
                  Polyline(
                    points: [activePath.last, previewPoint!],
                    color: Colors.orange,
                    strokeWidth: 6,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                ...nearbySourceStations.map(
                  (s) => _buildMarker(
                    s.name,
                    s.position,
                    Colors.green,
                    true,
                    refStation: s,
                  ),
                ),
                ..._getSortedRouteMarkers(),
                if (isPathEditing)
                  ...activePath.asMap().entries.map(
                    (e) => _buildPathNode(e.key, e.value),
                  ),
              ],
            ),
          ],
        ),
        if (isMapTapMode || isMoving)
          IgnorePointer(
            child: Center(
              child: isPathEditing
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isMoving
                              ? "${(movingPathIndex ?? 0) + 1}"
                              : "${activePath.length + 1}",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: const Icon(
                        Icons.location_on,
                        size: 42,
                        color: Colors.orange,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  Marker _buildPathNode(int index, LatLng point) => Marker(
    point: point,
    width: 20,
    height: 20,
    child: GestureDetector(
      onTap: (pathAddMode == PathAddMode.none && movingPathIndex == null)
          ? () => onPathPointTap(index)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: movingPathIndex == index ? Colors.blue : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: Center(
          child: Text(
            "${index + 1}",
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: movingPathIndex == index ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    ),
  );

  List<Marker> _getSortedRouteMarkers() {
    final activeList = isEditingGo ? goStations : backStations;
    final inactiveList = isEditingGo ? backStations : goStations;
    final markers = <Marker>[];
    final processed = <LatLng>{};
    final activePos = activeList.map((s) => LatLng(s.lat, s.lon)).toSet();
    final inactivePos = inactiveList.map((s) => LatLng(s.lat, s.lon)).toSet();

    for (var s in inactiveList) {
      final p = LatLng(s.lat, s.lon);
      if (activePos.contains(p)) continue;
      if (!processed.add(p)) continue;
      markers.add(
        _buildMarker(s.name, s.position, Colors.blue.withOpacity(0.7), true),
      );
    }

    for (var i = 0; i < activeList.length; i++) {
      final s = activeList[i];
      final p = LatLng(s.lat, s.lon);
      final bool overlap = inactivePos.contains(p);
      markers.add(
        _buildMarker(
          "${i + 1}. ${s.name}",
          s.position,
          movingStationIndex == i
              ? Colors.blue
              : (overlap ? Colors.red : Colors.orange),
          true,
          refStation: s,
        ),
      );
      processed.add(p);
    }
    return markers;
  }

  Marker _buildMarker(
    String label,
    LatLng point,
    Color color,
    bool canTap, {
    BusStation? refStation,
  }) => Marker(
    point: point,
    width: 120,
    height: 60,
    rotate: true,
    alignment: Alignment.topCenter,
    child: GestureDetector(
      onTap:
          (canTap &&
              !isPathEditing &&
              pathAddMode == PathAddMode.none &&
              movingStationIndex == null)
          ? () => onMarkerTap(
              point,
              refStation ??
                  BusStation(
                    order: 0,
                    name: label,
                    lat: point.latitude,
                    lon: point.longitude,
                  ),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.location_on,
            size: 28,
            color: color,
            shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
          ),
        ],
      ),
    ),
  );
}
