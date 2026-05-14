import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/bus_station.dart';

class MapViewSection extends StatelessWidget {
  final MapController mapController;
  final List<LatLng> goPath, backPath;
  final bool isEditingGo, isMapTapMode;
  final double brightness;
  final List<BusStation> nearbySourceStations, goStations, backStations;
  final Function(MapCamera) onPositionChanged;
  final Function(LatLng) onMapTap;
  final Function(LatLng, BusStation) onMarkerTap;

  const MapViewSection({
    super.key,
    required this.mapController,
    required this.goPath,
    required this.backPath,
    required this.isEditingGo,
    required this.brightness,
    required this.nearbySourceStations,
    required this.goStations,
    required this.backStations,
    required this.onPositionChanged,
    required this.onMapTap,
    required this.onMarkerTap,
    required this.isMapTapMode,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: const LatLng(24.9892, 121.3135),
        initialZoom: 16,
        onPositionChanged: (p, g) => onPositionChanged(p),
        onTap: (p, point) => onMapTap(point),
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
            if (goPath.isNotEmpty)
              Polyline(
                points: goPath,
                color: isEditingGo ? Colors.orange : Colors.blue,
                strokeWidth: 5,
              ),
            if (backPath.isNotEmpty)
              Polyline(
                points: backPath,
                color: !isEditingGo ? Colors.orange : Colors.blue,
                strokeWidth: 5,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            ...nearbySourceStations.map((s) => _buildMarker(s, Colors.green)),
            ..._getRouteMarkers(),
          ],
        ),
      ],
    );
  }

  List<Marker> _getRouteMarkers() {
    final status = <String, int>{};
    for (var s in goStations) status["${s.lat}_${s.lon}"] = 1;
    for (var s in backStations)
      status["${s.lat}_${s.lon}"] = (status["${s.lat}_${s.lon}"] ?? 0) | 2;
    final processed = <String>{};
    final markers = <Marker>[];
    for (var s in [...goStations, ...backStations]) {
      if (!processed.add("${s.lat}_${s.lon}")) continue;
      int state = status["${s.lat}_${s.lon}"]!;
      markers.add(
        _buildMarker(
          s,
          state == 3
              ? Colors.red
              : ((state == 1 && isEditingGo) || (state == 2 && !isEditingGo)
                    ? Colors.orange
                    : Colors.blue),
        ),
      );
    }
    return markers;
  }

  Marker _buildMarker(BusStation s, Color color) => Marker(
    point: s.position,
    width: 120,
    height: 60,
    rotate: true,
    alignment: Alignment.topCenter,
    child: GestureDetector(
      onTap: () => onMarkerTap(s.position, s),
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
              s.name,
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
