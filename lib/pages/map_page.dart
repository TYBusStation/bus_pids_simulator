import 'package:bus_pids_simulator/data/bus_station.dart';
import 'package:bus_pids_simulator/widgets/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../data/status.dart';
import '../utils/map_utils.dart';
import '../utils/route_engine.dart';
import '../utils/static.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  bool _isFollowing = true;
  double _satelliteOpacity = 1;
  bool _isFabMenuExpanded = false;

  List<Polyline> _userSelectedPolylines = [];
  List<Marker> _userSelectedMarkers = [];

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _handleAutoMove(LatLng? location, RouteAnalysisResult? result) {
    if (_isFollowing && location != null) {
      double rotation = 0;
      if (result != null && !result.isOffRoute && result.bearing != null) {
        rotation = -result.bearing!;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.moveAndRotate(
          location,
          _mapController.camera.zoom,
          rotation,
        );
      });
    }
  }

  void _recenterMap() {
    setState(() => _isFollowing = false);

    final List<LatLng> allPoints = [
      ..._userSelectedPolylines.expand((p) => p.points),
      ..._userSelectedMarkers.map((m) => m.point),
    ];

    if (allPoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
          maxZoom: MapUtils.defaultZoom,
        ),
      );
    }
  }

  void _updateRouteLayers() {
    final route = Static.currentStatus.route;
    final direction = Static.currentStatus.direction;
    const color = Colors.red;

    List<Polyline> polylines = [];
    List<Marker> markers = [];

    if (direction == Direction.go && route.path.goPoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: route.path.goPoints,
          color: color.withOpacity(0.9),
          strokeWidth: 5.0,
        ),
      );
      markers.addAll(
        route.stations.go.map(
          (s) => _createStationMarker(s, color.withOpacity(0.9)),
        ),
      );
    } else if (direction == Direction.back &&
        route.path.backPoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: route.path.backPoints,
          color: color.withOpacity(0.9),
          strokeWidth: 5.0,
        ),
      );
      markers.addAll(
        route.stations.back.map(
          (s) => _createStationMarker(s, color.withOpacity(0.9)),
        ),
      );
    }

    _userSelectedPolylines = polylines;
    _userSelectedMarkers = markers;
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
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              softWrap: true, // 支援長站名換行
            ),
          ),
          Icon(
            Icons.location_on,
            size: 36,
            color: color,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateRouteLayers();

    return LocationProvider(
      builder: (context, currentLocation) {
        RouteAnalysisResult? analysis;
        if (currentLocation != null &&
            Static.currentStatus.dutyStatus == DutyStatus.onDuty) {
          final points = Static.currentStatus.direction == Direction.go
              ? Static.currentStatus.route.path.goPoints
              : Static.currentStatus.route.path.backPoints;
          final stations = Static.currentStatus.direction == Direction.go
              ? Static.currentStatus.route.stations.go
              : Static.currentStatus.route.stations.back;

          if (points.isNotEmpty && stations.isNotEmpty) {
            analysis = RouteEngine.analyze(
              currentPos: currentLocation,
              routePoints: points,
              stations: stations,
            );
          }
        }

        _handleAutoMove(currentLocation, analysis);

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(24.98893444390252, 121.31443803557084),
                initialZoom: MapUtils.defaultZoom,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && _isFollowing) {
                    setState(() => _isFollowing = false);
                  }
                },
              ),
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.6, 0, 0, 0, 0, // 降低 R 亮度至 60%
                    0, 0.6, 0, 0, 0, // 降低 G 亮度至 60%
                    0, 0, 0.6, 0, 0, // 降低 B 亮度至 60%
                    0, 0, 0, 1, 0,
                  ]),
                  child: Opacity(
                    opacity: _satelliteOpacity,
                    child: TileLayer(
                      urlTemplate:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      tileProvider: NetworkTileProvider(),
                    ),
                  ),
                ),
                TileLayer(
                  urlTemplate:
                      'https://wmts.nlsc.gov.tw/wmts/EMAP2/default/GoogleMapsCompatible/{z}/{y}/{x}',
                  tileProvider: NetworkTileProvider(),
                ),
                PolylineLayer(polylines: _userSelectedPolylines),
                MarkerLayer(
                  markers: [
                    ..._userSelectedMarkers,
                    if (currentLocation != null)
                      Marker(
                        point: currentLocation,
                        width: 25,
                        height: 25,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (analysis != null) _buildTopInfoOverlay(analysis),
            Positioned(bottom: 20, right: 16, child: _buildMapControls()),
          ],
        );
      },
    );
  }

  Widget _buildTopInfoOverlay(RouteAnalysisResult res) {
    final status = Static.currentStatus;
    final directionText = status.direction == Direction.go
        ? status.route.destination
        : status.route.departure;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          border: const Border(
            bottom: BorderSide(color: Colors.white24, width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "上一站",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        res.prevStation?.name ?? "起點站",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (res.distToPrevStation != null)
                        Text(
                          "${res.distToPrevStation!.toStringAsFixed(0)}m 前",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.route.name,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        status.route.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "往 $directionText ${res.isOffRoute ? '(脫離路線)' : ''}",
                        style: TextStyle(
                          color: res.isOffRoute
                              ? Colors.redAccent
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: res.isOffRoute
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "下一站",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        res.nextStation?.name ?? "終點站",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (res.distToNextStation != null)
                        Text(
                          "${res.distToNextStation!.toStringAsFixed(0)}m",
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFabMenuExpanded)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  width: 40,
                  height: 120,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.satellite_alt_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2.0,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6.0,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12.0,
                              ),
                            ),
                            child: Slider(
                              value: _satelliteOpacity,
                              activeColor: theme.colorScheme.primary,
                              onChanged: (v) =>
                                  setState(() => _satelliteOpacity = v),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FloatingActionButton.small(
                onPressed: _recenterMap,
                tooltip: '重新置中',
                elevation: 4,
                heroTag: 'recenter_btn_nearby',
                child: const Icon(Icons.center_focus_strong),
              ),
              const SizedBox(height: 4),
              FloatingActionButton.small(
                onPressed: () {
                  final locProvider = context.read<LocationChangeNotifier>();
                  if (locProvider.currentLocation != null) {
                    setState(() => _isFollowing = true);
                    _mapController.move(locProvider.currentLocation!, 17.0);
                  }
                },
                tooltip: '定位我的位置',
                elevation: 4,
                backgroundColor:
                    theme.floatingActionButtonTheme.backgroundColor,
                heroTag: 'locate_me_btn_nearby',
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        const SizedBox(height: 4),
        FloatingActionButton(
          onPressed: () =>
              setState(() => _isFabMenuExpanded = !_isFabMenuExpanded),
          tooltip: _isFabMenuExpanded ? '關閉選單' : '開啟選單',
          elevation: 4,
          heroTag: 'main_fab_toggle',
          child: Icon(_isFabMenuExpanded ? Icons.close : Icons.menu_open),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
