import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../data/bus_route.dart';
import '../data/bus_station.dart';
import '../data/route_path.dart';
import '../data/route_stations.dart';
import '../data/status.dart';
import '../utils/static.dart';
import '../widgets/route_analysis_provider.dart';
import '../widgets/status_provider.dart';

class RouteEditorPage extends StatefulWidget {
  final BusRoute? initialRoute;

  const RouteEditorPage({super.key, this.initialRoute});

  @override
  State<RouteEditorPage> createState() => _RouteEditorPageState();
}

class _RouteEditorPageState extends State<RouteEditorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _depCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _wktGoCtrl = TextEditingController();
  final _wktBackCtrl = TextEditingController();
  final _jsonCtrl = TextEditingController();
  List<BusStation> _goStations = [];
  List<BusStation> _backStations = [];
  List<LatLng> _goPath = [];
  List<LatLng> _backPath = [];
  bool _isEditingGo = true;
  bool _isMapTapMode = false;
  bool _autoWktGo = false;
  bool _autoWktBack = false;
  bool _isFabMenuExpanded = false;
  final MapController _mapController = MapController();
  Set<String> _selectedSources = {'Taoyuan'};
  List<BusStation> _allSourceStations = [];
  List<BusStation> _nearbySourceStations = [];
  double _brightness = 0.6;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) _updateJsonField();
    });
    if (widget.initialRoute != null) {
      final r = widget.initialRoute!;
      _idCtrl.text = r.id;
      _nameCtrl.text = r.name;
      _descCtrl.text = r.description;
      _depCtrl.text = r.departure;
      _destCtrl.text = r.destination;
      _wktGoCtrl.text = r.path.go;
      _wktBackCtrl.text = r.path.back;
      _goStations = List.from(r.stations.go);
      _backStations = List.from(r.stations.back);
    }
    _syncPaths();
    _loadSourceStations();
  }

  void _syncPaths() {
    setState(() {
      if (_autoWktGo) {
        _goPath = _goStations.map((s) => LatLng(s.lat, s.lon)).toList();
        _wktGoCtrl.text = _generateWktFromStations(_goStations);
      } else {
        _goPath = Static.wktPrase(_wktGoCtrl.text);
      }
      if (_autoWktBack) {
        _backPath = _backStations.map((s) => LatLng(s.lat, s.lon)).toList();
        _wktBackCtrl.text = _generateWktFromStations(_backStations);
      } else {
        _backPath = Static.wktPrase(_wktBackCtrl.text);
      }
    });
  }

  String _generateWktFromStations(List<BusStation> stations) {
    if (stations.length < 2) return "";
    return "LINESTRING (${stations.map((s) => "${s.lon} ${s.lat}").join(", ")})";
  }

  void _updateJsonField() {
    _jsonCtrl.text = const JsonEncoder.withIndent(
      '  ',
    ).convert(_prepareRouteData().toJson());
  }

  BusRoute _prepareRouteData() {
    String routeId = _idCtrl.text.trim();
    if (routeId.isEmpty) {
      final customRoutes = Static.routeData['Custom'] ?? [];
      final existingIds = customRoutes.map((r) => r.id).toSet();
      int i = 0;
      while (existingIds.contains(i.toString())) i++;
      routeId = i.toString();
    }
    return BusRoute(
      id: routeId,
      name: _nameCtrl.text,
      description: _descCtrl.text,
      departure: _depCtrl.text,
      destination: _destCtrl.text,
      path: RoutePath(go: _wktGoCtrl.text, back: _wktBackCtrl.text),
      stations: RouteStations(
        go: _assignOrders(_goStations),
        back: _assignOrders(_backStations),
      ),
    );
  }

  List<BusStation> _assignOrders(List<BusStation> stations) => List.generate(
    stations.length,
    (i) => BusStation(
      order: i + 1,
      name: stations[i].name,
      nameEn: stations[i].nameEn,
      lat: stations[i].lat,
      lon: stations[i].lon,
    ),
  );

  Future<void> _handleSave() async {
    final route = _prepareRouteData();
    final oldId = widget.initialRoute?.id;
    await Static.saveCustomRoute(route, oldId: oldId);
    if (Static.currentStatus.route.id == (oldId ?? route.id)) {
      final newStatus = Status(
        route: route,
        direction: Static.currentStatus.direction,
        dutyStatus: DutyStatus.offDuty,
      );
      Static.currentStatus = newStatus;
      if (mounted) {
        context.read<RouteAnalysisProvider>().resetAnalysis();
        context.read<StatusChangeNotifier>().setStatus(newStatus);
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  void _loadSourceStations() {
    final List<BusStation> temp = [];
    final Set<String> seen = {};
    for (var src in _selectedSources) {
      for (var r in (Static.routeData[src] ?? [])) {
        for (var s in [...r.stations.go, ...r.stations.back]) {
          if (seen.add(
            "${s.lat.toStringAsFixed(5)}_${s.lon.toStringAsFixed(5)}",
          ))
            temp.add(s);
        }
      }
    }
    _allSourceStations = temp;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _filterNearbyStations(_mapController.camera.center);
    });
  }

  void _filterNearbyStations(LatLng center) => setState(
    () => _nearbySourceStations = _allSourceStations
        .where(
          (s) =>
              Geolocator.distanceBetween(
                center.latitude,
                center.longitude,
                s.lat,
                s.lon,
              ) <=
              500,
        )
        .toList(),
  );

  void _recenterMap() {
    final all = [
      ..._goPath,
      ..._backPath,
      ..._goStations.map((e) => e.position),
      ..._backStations.map((e) => e.position),
    ].where((p) => p.latitude.isFinite).toList();
    if (all.isNotEmpty)
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(all),
          padding: const EdgeInsets.all(50),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 45,
          title: const Text("路線編輯", style: TextStyle(fontSize: 14)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              child: FilledButton.icon(
                onPressed: _handleSave,
                icon: const Icon(Icons.save, size: 18),
                label: const Text("儲存"),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "視覺編輯"),
              Tab(text: "JSON"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildGui(), _buildJson()],
        ),
      ),
    );
  }

  Widget _buildGui() {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _idCtrl,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: "ID",
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: "名稱",
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _descCtrl,
                      style: const TextStyle(fontSize: 11),
                      decoration: const InputDecoration(
                        labelText: "描述",
                        isDense: true,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _depCtrl,
                            style: const TextStyle(fontSize: 11),
                            decoration: const InputDecoration(
                              labelText: "起點",
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _destCtrl,
                            style: const TextStyle(fontSize: 11),
                            decoration: const InputDecoration(
                              labelText: "終點",
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDirBtn(true, "去程"),
                        _buildDirBtn(false, "回程"),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _isEditingGo
                                ? _wktGoCtrl
                                : _wktBackCtrl,
                            enabled: !(_isEditingGo
                                ? _autoWktGo
                                : _autoWktBack),
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              hintText: "WKT Path",
                            ),
                            onChanged: (_) => _syncPaths(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Column(
                          children: [
                            const Text("自動", style: TextStyle(fontSize: 8)),
                            SizedBox(
                              height: 20,
                              width: 32,
                              child: Transform.scale(
                                scale: 0.6,
                                child: Switch(
                                  value: _isEditingGo
                                      ? _autoWktGo
                                      : _autoWktBack,
                                  onChanged: (v) {
                                    setState(() {
                                      if (_isEditingGo)
                                        _autoWktGo = v;
                                      else
                                        _autoWktBack = v;
                                    });
                                    _syncPaths();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount:
                      (_isEditingGo ? _goStations : _backStations).length,
                  onReorder: (o, n) {
                    setState(() {
                      final list = _isEditingGo ? _goStations : _backStations;
                      if (n > o) n -= 1;
                      list.insert(n, list.removeAt(o));
                    });
                    _syncPaths();
                  },
                  itemBuilder: (ctx, i) {
                    final s = (_isEditingGo ? _goStations : _backStations)[i];
                    return ListTile(
                      key: ValueKey("${_isEditingGo ? 'g' : 'b'}$i"),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: SizedBox(
                        width: 50,
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: const Icon(
                                Icons.drag_indicator,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.orange,
                              child: Text(
                                "${i + 1}",
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(s.name, style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () {
                          setState(
                            () => (_isEditingGo ? _goStations : _backStations)
                                .removeAt(i),
                          );
                          _syncPaths();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(24.9892, 121.3135),
                  initialZoom: 16,
                  onPositionChanged: (p, g) => _filterNearbyStations(p.center),
                  onTap: (p, point) {
                    if (_isMapTapMode) {
                      setState(() => _isMapTapMode = false);
                      _showStationDialog(point);
                    }
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
                  PolylineLayer(
                    polylines: [
                      if (_goPath.isNotEmpty)
                        Polyline(
                          points: _goPath,
                          color: _isEditingGo ? Colors.orange : Colors.blue,
                          strokeWidth: 5,
                        ),
                      if (_backPath.isNotEmpty)
                        Polyline(
                          points: _backPath,
                          color: !_isEditingGo ? Colors.orange : Colors.blue,
                          strokeWidth: 5,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      ..._nearbySourceStations.map(
                        (s) => _buildMarker(s, color: Colors.green),
                      ),
                      ..._getRouteMarkers(),
                    ],
                  ),
                ],
              ),
              Positioned(bottom: 20, right: 85, child: _buildMapControls()),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  width: 75,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.9),
                    border: Border(left: BorderSide(color: theme.dividerColor)),
                  ),
                  child: ListView(
                    children:
                        {
                              'Taoyuan': '桃園市',
                              'Taipei': '臺北市',
                              'NewTaipei': '新北市',
                              'Taichung': '臺中市',
                              'InterCity': '公路客運',
                            }.entries
                            .map(
                              (e) => InkWell(
                                onTap: () => setState(() {
                                  if (_selectedSources.contains(e.key))
                                    _selectedSources.remove(e.key);
                                  else
                                    _selectedSources.add(e.key);
                                  _loadSourceStations();
                                }),
                                child: Container(
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: theme.dividerColor,
                                        width: 0.5,
                                      ),
                                    ),
                                    color: _selectedSources.contains(e.key)
                                        ? theme.colorScheme.primary.withOpacity(
                                            0.3,
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    e.value,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _selectedSources.contains(e.key)
                                          ? theme.colorScheme.primary
                                          : Colors.white70,
                                      fontWeight:
                                          _selectedSources.contains(e.key)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirBtn(bool isGo, String label) => Expanded(
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _isEditingGo == isGo
            ? Colors.orange
            : Colors.grey[850],
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 32),
      ),
      onPressed: () => setState(() => _isEditingGo = isGo),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    ),
  );

  List<Marker> _getRouteMarkers() {
    final status = <String, int>{};
    for (var s in _goStations) status["${s.lat}_${s.lon}"] = 1;
    for (var s in _backStations)
      status["${s.lat}_${s.lon}"] = (status["${s.lat}_${s.lon}"] ?? 0) | 2;
    final processed = <String>{};
    final markers = <Marker>[];
    for (var s in [..._goStations, ..._backStations]) {
      if (!processed.add("${s.lat}_${s.lon}")) continue;
      int state = status["${s.lat}_${s.lon}"]!;
      markers.add(
        _buildMarker(
          s,
          color: state == 3
              ? Colors.red
              : ((state == 1 && _isEditingGo) || (state == 2 && !_isEditingGo)
                    ? Colors.orange
                    : Colors.blue),
        ),
      );
    }
    return markers;
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
                  onPressed: _recenterMap,
                  heroTag: 'rec',
                  child: const Icon(Icons.center_focus_strong, size: 16),
                ),
              ),
              const SizedBox(width: 4),
            ],
            SizedBox(
              width: 34,
              height: 34,
              child: FloatingActionButton.small(
                onPressed: () => setState(() => _isMapTapMode = !_isMapTapMode),
                backgroundColor: _isMapTapMode
                    ? Colors.orange
                    : theme.colorScheme.surface,
                heroTag: 'add',
                child: Icon(
                  Icons.add_location_alt,
                  size: 16,
                  color: _isMapTapMode
                      ? Colors.white
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
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

  Marker _buildMarker(BusStation s, {required Color color}) => Marker(
    point: s.position,
    width: 120,
    height: 60,
    rotate: true,
    alignment: Alignment.topCenter,
    child: GestureDetector(
      onTap: () => _showStationDialog(s.position, existing: s),
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

  void _showStationDialog(LatLng p, {BusStation? existing}) {
    final list = _isEditingGo ? _goStations : _backStations;
    final n = TextEditingController(text: existing?.name ?? "");
    final o = TextEditingController(text: (list.length + 1).toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("站點", style: TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(labelText: "站名"),
            ),
            TextField(
              controller: o,
              decoration: const InputDecoration(labelText: "順序"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          if (list.any((s) => s.lat == p.latitude && s.lon == p.longitude))
            TextButton(
              onPressed: () {
                setState(
                  () => list.removeWhere(
                    (s) => s.lat == p.latitude && s.lon == p.longitude,
                  ),
                );
                _syncPaths();
                Navigator.pop(ctx);
              },
              child: const Text("移除", style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () {
              final s = BusStation(
                order: 0,
                name: n.text,
                nameEn: existing?.nameEn ?? "",
                lat: p.latitude,
                lon: p.longitude,
              );
              int pos = int.tryParse(o.text) ?? 1;
              setState(() {
                if (pos > 0 && pos <= list.length)
                  list.insert(pos - 1, s);
                else
                  list.add(s);
              });
              _syncPaths();
              Navigator.pop(ctx);
            },
            child: const Text("加入"),
          ),
        ],
      ),
    );
  }

  Widget _buildJson() => Padding(
    padding: const EdgeInsets.all(12),
    child: TextField(
      controller: _jsonCtrl,
      maxLines: null,
      expands: true,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      decoration: const InputDecoration(border: OutlineInputBorder()),
    ),
  );
}
