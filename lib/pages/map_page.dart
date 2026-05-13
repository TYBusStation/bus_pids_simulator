import 'package:bus_pids_simulator/data/bus_station.dart';
import 'package:bus_pids_simulator/widgets/location_provider.dart';
import 'package:bus_pids_simulator/widgets/route_analysis_provider.dart';
import 'package:bus_pids_simulator/widgets/status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../data/status.dart';
import '../utils/route_engine.dart';
import '../widgets/map_bottom_panel.dart';

class MapPage extends StatefulWidget {
  final bool showBottomInfo;
  final VoidCallback onToggleBottomInfo;

  const MapPage({
    super.key,
    required this.showBottomInfo,
    required this.onToggleBottomInfo,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  bool _isFollowing = true;
  double _brightness = 0.6;
  bool _isFabMenuExpanded = false;
  final GlobalKey<MapBottomPanelState> _bottomPanelKey = GlobalKey();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _handleAutoMove(LatLng? location, RouteAnalysisResult? result) {
    if (location != null &&
        location.latitude.isFinite &&
        location.longitude.isFinite &&
        _isFollowing) {
      double rotation = 0;
      if (result != null &&
          !result.isOffRoute &&
          result.bearing != null &&
          result.bearing!.isFinite) {
        rotation = -result.bearing!;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.moveAndRotate(location, 17.5, rotation);
        }
      });
    }
  }

  void _recenterMap(List<Polyline> polylines, List<Marker> markers) {
    setState(() => _isFollowing = false);
    final List<LatLng> allPoints = [
      ...polylines.expand((p) => p.points),
      ...markers.map((m) => m.point),
    ].where((p) => p.latitude.isFinite && p.longitude.isFinite).toList();
    if (allPoints.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(allPoints),
          padding: const EdgeInsets.all(50),
          maxZoom: 17,
        ),
      );
    }
  }

  Marker _createStationMarker(BusStation station, Color color) {
    return Marker(
      point: station.position,
      width: 200,
      height: 100,
      rotate: true,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Text(
              "${station.order}. ${station.name}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Icon(
            Icons.location_on,
            size: 32,
            color: color,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer3<
      LocationChangeNotifier,
      RouteAnalysisProvider,
      StatusChangeNotifier
    >(
      builder: (context, locNotifier, analysisProvider, statusNotifier, child) {
        final status = statusNotifier.currentStatus;
        final route = status.route;
        final direction = status.direction;
        final currentLocation = locNotifier.currentLocation;
        final analysis = analysisProvider.currentAnalysis;
        final bool isValidLocation =
            currentLocation != null &&
            currentLocation.latitude.isFinite &&
            currentLocation.longitude.isFinite;
        _handleAutoMove(currentLocation, analysis);
        List<LatLng> points =
            (direction == Direction.go
                    ? route.path.goPoints
                    : route.path.backPoints)
                .where((p) => p.latitude.isFinite && p.longitude.isFinite)
                .toList();
        final List<Polyline> polylines = points.isNotEmpty
            ? [
                Polyline(
                  points: points,
                  color: Colors.red.withOpacity(0.9),
                  strokeWidth: 5.0,
                ),
              ]
            : [];
        final List<Marker> stationMarkers =
            (direction == Direction.go
                    ? route.stations.go
                    : route.stations.back)
                .where(
                  (s) =>
                      s.position.latitude.isFinite &&
                      s.position.longitude.isFinite,
                )
                .map(
                  (s) => _createStationMarker(s, Colors.red.withOpacity(0.9)),
                )
                .toList();
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: isValidLocation
                    ? currentLocation
                    : const LatLng(24.9889, 121.3144),
                initialZoom: 17.5,
                onPositionChanged: (p, g) {
                  if (g && _isFollowing) setState(() => _isFollowing = false);
                },
              ),
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.matrix([
                    _brightness,
                    0,
                    0,
                    0,
                    0,
                    0,
                    _brightness,
                    0,
                    0,
                    0,
                    0,
                    0,
                    _brightness,
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
                PolylineLayer(polylines: polylines),
                MarkerLayer(
                  markers: [
                    ...stationMarkers,
                    if (isValidLocation)
                      Marker(
                        point: currentLocation,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (widget.showBottomInfo)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: MapBottomPanel(
                  key: _bottomPanelKey,
                  analysis: analysis,
                  stations: direction == Direction.go
                      ? route.stations.go
                      : route.stations.back,
                ),
              ),
            Positioned(
              bottom: widget.showBottomInfo ? 35 : 0,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: widget.onToggleBottomInfo,
                  child: Container(
                    width: 40,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                    child: Icon(
                      widget.showBottomInfo
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: widget.showBottomInfo ? 45 : 10,
              right: 15,
              child: _buildMapControls(polylines, stationMarkers),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapControls(List<Polyline> polylines, List<Marker> markers) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFabMenuExpanded) ...[
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              width: 32,
              height: 90,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.brightness_6,
                    size: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 1.5,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 4.0,
                          ),
                        ),
                        child: Slider(
                          value: _brightness,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (v) => setState(() => _brightness = v),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isFabMenuExpanded) ...[
              SizedBox(
                width: 34,
                height: 34,
                child: FloatingActionButton.small(
                  onPressed: () => _recenterMap(polylines, markers),
                  heroTag: 'rec',
                  child: const Icon(Icons.center_focus_strong, size: 16),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 34,
                height: 34,
                child: FloatingActionButton.small(
                  onPressed: () {
                    setState(() => _isFollowing = !_isFollowing);
                    if (_isFollowing) {
                      _bottomPanelKey.currentState?.scrollToCurrent();
                    }
                  },
                  backgroundColor: _isFollowing
                      ? theme.colorScheme.primaryContainer
                      : null,
                  heroTag: 'fol',
                  child: Icon(
                    _isFollowing ? Icons.my_location : Icons.location_searching,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            SizedBox(
              width: 38,
              height: 38,
              child: FloatingActionButton(
                onPressed: () =>
                    setState(() => _isFabMenuExpanded = !_isFabMenuExpanded),
                heroTag: 'm',
                child: Icon(
                  _isFabMenuExpanded ? Icons.close : Icons.menu_open,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
