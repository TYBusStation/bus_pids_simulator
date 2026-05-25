import 'package:bus_pids_simulator/data/bus_station.dart';
import 'package:bus_pids_simulator/widgets/location_provider.dart';
import 'package:bus_pids_simulator/widgets/route_analysis_provider.dart';
import 'package:bus_pids_simulator/widgets/status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../data/status.dart';
import '../widgets/map_bottom_panel.dart';
import 'main_page.dart';

class MapPage extends StatefulWidget {
  final GlobalKey<MapBottomPanelState> bottomPanelKey;
  final bool isVisible;

  const MapPage({
    super.key,
    required this.bottomPanelKey,
    required this.isVisible,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  bool _isFollowing = true;
  double _brightness = 0.6;
  bool _isFabMenuExpanded = false;
  List<Polyline> _cachedPolylines = [];
  List<Marker> _cachedStationMarkers = [];
  String _lastRouteKey = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouteAnalysisProvider>().addListener(_onAnalysisUpdate);
    });
  }

  @override
  void dispose() {
    context.read<RouteAnalysisProvider>().removeListener(_onAnalysisUpdate);
    _mapController.dispose();
    super.dispose();
  }

  void _onAnalysisUpdate() {
    if (!mounted || !_isFollowing || !widget.isVisible) return;
    final analysisProvider = context.read<RouteAnalysisProvider>();
    final locNotifier = context.read<LocationChangeNotifier>();
    final analysis = analysisProvider.currentAnalysis;
    final loc = locNotifier.currentLocation;
    if (loc != null && loc.latitude.isFinite && loc.longitude.isFinite) {
      double rotation = 0;
      if (analysis != null &&
          !analysis.isOffRoute &&
          analysis.bearing != null) {
        rotation = -analysis.bearing!;
      }
      _mapController.moveAndRotate(loc, 17.5, rotation);
    }
  }

  void _updateCache(Status status) {
    final key = "${status.route.id}_${status.direction}";
    if (_lastRouteKey == key) return;
    _lastRouteKey = key;
    final pts =
        (status.direction == Direction.go
                ? status.route.path.goPoints
                : status.route.path.backPoints)
            .where((p) => p.latitude.isFinite && p.longitude.isFinite)
            .toList();
    _cachedPolylines = pts.isNotEmpty
        ? [
            Polyline(
              points: pts,
              color: Colors.red.withOpacity(0.9),
              strokeWidth: 5.0,
            ),
          ]
        : [];
    _cachedStationMarkers =
        (status.direction == Direction.go
                ? status.route.stations.go
                : status.route.stations.back)
            .where(
              (s) =>
                  s.position.latitude.isFinite && s.position.longitude.isFinite,
            )
            .map((s) => _createStationMarker(s))
            .toList();
  }

  void _recenterMap() {
    setState(() => _isFollowing = false);
    final pts = [
      ..._cachedPolylines.expand((p) => p.points),
      ..._cachedStationMarkers.map((m) => m.point),
    ];
    if (pts.isNotEmpty)
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(50),
          maxZoom: 17,
        ),
      );
  }

  Marker _createStationMarker(BusStation s) {
    return Marker(
      point: s.position,
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
              "${s.order}. ${s.name}",
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
            color: Colors.red.withOpacity(0.9),
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final mainPage = context.findAncestorWidgetOfExactType<MainPage>();
    final double bottomPadding = (mainPage?.showBottomInfo ?? true) ? 45 : 15;
    return RepaintBoundary(
      child: Stack(
        children: [
          Consumer2<StatusChangeNotifier, LocationChangeNotifier>(
            builder: (context, statusNotifier, locNotifier, child) {
              _updateCache(statusNotifier.currentStatus);
              final loc = locNotifier.currentLocation;
              final hasLoc =
                  loc != null &&
                  loc.latitude.isFinite &&
                  loc.longitude.isFinite;
              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: hasLoc ? loc : const LatLng(24.9889, 121.3144),
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
                  PolylineLayer(polylines: _cachedPolylines),
                  MarkerLayer(markers: _cachedStationMarkers),
                  if (hasLoc)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: loc,
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
          Positioned(
            bottom: bottomPadding,
            right: 15,
            child: _buildMapControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls() {
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
                children: [
                  const Icon(Icons.brightness_6, size: 14),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 1.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 4.0,
                          ),
                        ),
                        child: Slider(
                          value: _brightness,
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
          children: [
            if (_isFabMenuExpanded) ...[
              SizedBox(
                width: 34,
                height: 34,
                child: FloatingActionButton.small(
                  onPressed: _recenterMap,
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
                    if (_isFollowing)
                      widget.bottomPanelKey.currentState?.scrollToCurrent();
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
