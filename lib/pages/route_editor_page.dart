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
import '../widgets/editor/editor_side_panel.dart';
import '../widgets/editor/map_controls.dart';
import '../widgets/editor/map_view_section.dart';
import '../widgets/editor/source_sidebar.dart';
import '../widgets/editor/station_dialog.dart';
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
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 1) {
          _updateJsonField();
        } else {
          _parseJsonField();
        }
      }
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _recenterMap());
  }

  void _updateJsonField() {
    _jsonCtrl.text = const JsonEncoder.withIndent(
      '  ',
    ).convert(_prepareRouteData().toJson());
  }

  bool _parseJsonField() {
    if (_jsonCtrl.text.trim().isEmpty) return false;
    try {
      final Map<String, dynamic> data = jsonDecode(_jsonCtrl.text);
      final newRoute = BusRoute.fromJson(data);

      setState(() {
        _idCtrl.text = newRoute.id;
        _nameCtrl.text = newRoute.name;
        _descCtrl.text = newRoute.description;
        _depCtrl.text = newRoute.departure;
        _destCtrl.text = newRoute.destination;
        _wktGoCtrl.text = newRoute.path.go;
        _wktBackCtrl.text = newRoute.path.back;
        _goStations = List.from(newRoute.stations.go);
        _backStations = List.from(newRoute.stations.back);

        _autoWktGo = false;
        _autoWktBack = false;
      });
      _syncPaths();
      return true;
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("JSON 格式錯誤"),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("確定"),
              ),
            ],
          ),
        );
      }
      return false;
    }
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

  double _getDistanceToPath(LatLng point, List<LatLng> path) {
    if (path.isEmpty) return double.infinity;
    if (path.length == 1)
      return Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        path[0].latitude,
        path[0].longitude,
      );
    double minDistance = double.infinity;
    for (int i = 0; i < path.length - 1; i++) {
      LatLng a = path[i];
      LatLng b = path[i + 1];
      double x = point.longitude;
      double y = point.latitude;
      double x1 = a.longitude;
      double y1 = a.latitude;
      double x2 = b.longitude;
      double y2 = b.latitude;
      double dx = x2 - x1;
      double dy = y2 - y1;
      if (dx == 0 && dy == 0) {
        double d = Geolocator.distanceBetween(y, x, y1, x1);
        if (d < minDistance) minDistance = d;
        continue;
      }
      double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
      t = t.clamp(0.0, 1.0);
      double closestX = x1 + t * dx;
      double closestY = y1 + t * dy;
      double d = Geolocator.distanceBetween(y, x, closestY, closestX);
      if (d < minDistance) minDistance = d;
    }
    return minDistance;
  }

  Future<void> _handleSave() async {
    if (_tabController.index == 1) {
      if (!_parseJsonField()) return;
    }

    List<String> wktErrors = [];
    List<String> distanceErrors = [];
    if (!_autoWktGo && _goStations.isNotEmpty) {
      if (_wktGoCtrl.text.trim().isEmpty)
        wktErrors.add("去程路線線形 WKT 為空");
      else {
        List<String> far = [];
        for (var s in _goStations) {
          if (_getDistanceToPath(LatLng(s.lat, s.lon), _goPath) > 100)
            far.add(s.name);
        }
        if (far.isNotEmpty) distanceErrors.add("去程站點偏離：${far.join('、')}");
      }
    }
    if (!_autoWktBack && _backStations.isNotEmpty) {
      if (_wktBackCtrl.text.trim().isEmpty)
        wktErrors.add("回程路線線形 WKT 為空");
      else {
        List<String> far = [];
        for (var s in _backStations) {
          if (_getDistanceToPath(LatLng(s.lat, s.lon), _backPath) > 100)
            far.add(s.name);
        }
        if (far.isNotEmpty) distanceErrors.add("回程站點偏離：${far.join('、')}");
      }
    }
    if (wktErrors.isNotEmpty || distanceErrors.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("儲存警告", style: TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wktErrors.isNotEmpty) ...[
                  const Text(
                    "【路線線形缺失】",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  ...wktErrors.map(
                    (e) => Text("• $e", style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                ],
                if (distanceErrors.isNotEmpty) ...[
                  const Text(
                    "【站點偏離】",
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  ...distanceErrors.map(
                    (e) => Text("• $e", style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                const Text(
                  "可開啟「自動」模式，將自動連線站點位置生成路線線形。",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("返回修改"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("仍要儲存", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
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
      final routes = Static.routeData[src];
      if (routes == null) continue;
      for (var r in routes) {
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
    ].where((p) => p.latitude.isFinite && p.longitude.isFinite).toList();
    if (all.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(all),
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  void _onMapStationTap(LatLng p, {BusStation? existing}) async {
    final list = _isEditingGo ? _goStations : _backStations;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) =>
          StationDialog(point: p, existing: existing, currentList: list),
    );
    if (result != null) {
      setState(() {
        if (result['action'] == 'delete' && existing != null)
          list.remove(existing);
        else if (result['action'] == 'save') {
          final s = result['station'] as BusStation;
          final pos = result['order'] as int;
          if (pos > 0 && pos <= list.length)
            list.insert(pos - 1, s);
          else
            list.add(s);
        }
      });
      _syncPaths();
    }
  }

  void _onStationListEdit(int index, BusStation s) async {
    final list = _isEditingGo ? _goStations : _backStations;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => EditStationNameDialog(name: s.name, nameEn: s.nameEn),
    );
    if (result != null) {
      setState(() {
        list[index] = BusStation(
          order: s.order,
          name: result['name'] ?? "",
          nameEn: result['nameEn'] ?? "",
          lat: s.lat,
          lon: s.lon,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 35,
          title: const Text("路線編輯", style: TextStyle(fontSize: 13)),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: FilledButton.icon(
                onPressed: _handleSave,
                icon: const Icon(Icons.save, size: 14),
                label: const Text("儲存", style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: EdgeInsets.zero,
              tabs: const [
                Tab(
                  height: 30,
                  child: Text("視覺編輯", style: TextStyle(fontSize: 12)),
                ),
                Tab(
                  height: 30,
                  child: Text("JSON", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
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
    return Row(
      children: [
        EditorSidePanel(
          idCtrl: _idCtrl,
          nameCtrl: _nameCtrl,
          descCtrl: _descCtrl,
          depCtrl: _depCtrl,
          destCtrl: _destCtrl,
          wktCtrl: _isEditingGo ? _wktGoCtrl : _wktBackCtrl,
          isEditingGo: _isEditingGo,
          autoWkt: _isEditingGo ? _autoWktGo : _autoWktBack,
          stations: _isEditingGo ? _goStations : _backStations,
          onDirectionChanged: (v) => setState(() => _isEditingGo = v),
          onAutoWktChanged: (v) {
            setState(() {
              if (_isEditingGo)
                _autoWktGo = v;
              else
                _autoWktBack = v;
            });
            _syncPaths();
          },
          onWktManualChanged: _syncPaths,
          onReorder: (o, n) {
            setState(() {
              final list = _isEditingGo ? _goStations : _backStations;
              if (n > o) n -= 1;
              list.insert(n, list.removeAt(o));
            });
            _syncPaths();
          },
          onStationRemove: (i) {
            setState(
              () => (_isEditingGo ? _goStations : _backStations).removeAt(i),
            );
            _syncPaths();
          },
          onStationTap: (i, s) => _onStationListEdit(i, s),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Stack(
            children: [
              MapViewSection(
                mapController: _mapController,
                goPath: _goPath,
                backPath: _backPath,
                isEditingGo: _isEditingGo,
                brightness: _brightness,
                nearbySourceStations: _nearbySourceStations,
                goStations: _goStations,
                backStations: _backStations,
                isMapTapMode: _isMapTapMode,
                onPositionChanged: (p) => _filterNearbyStations(p.center),
                onMapTap: (p) {
                  if (_isMapTapMode) {
                    setState(() => _isMapTapMode = false);
                    _onMapStationTap(p);
                  }
                },
                onMarkerTap: (p, s) => _onMapStationTap(p, existing: s),
              ),
              Positioned(
                bottom: 20,
                right: 85,
                child: MapControls(
                  isFabMenuExpanded: _isFabMenuExpanded,
                  isMapTapMode: _isMapTapMode,
                  brightness: _brightness,
                  onToggleFab: () =>
                      setState(() => _isFabMenuExpanded = !_isFabMenuExpanded),
                  onToggleTapMode: () =>
                      setState(() => _isMapTapMode = !_isMapTapMode),
                  onRecenter: _recenterMap,
                  onBrightnessChanged: (v) => setState(() => _brightness = v),
                ),
              ),
              SourceSidebar(
                selectedSources: _selectedSources,
                onSourceToggle: (key) {
                  setState(() {
                    if (_selectedSources.contains(key))
                      _selectedSources.remove(key);
                    else
                      _selectedSources.add(key);
                  });
                  _loadSourceStations();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJson() => Padding(
    padding: const EdgeInsets.all(12),
    child: TextField(
      controller: _jsonCtrl,
      maxLines: null,
      expands: true,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: "在此貼上 JSON 格式的路線資料...",
      ),
    ),
  );
}

class EditStationNameDialog extends StatefulWidget {
  final String name;
  final String nameEn;

  const EditStationNameDialog({
    super.key,
    required this.name,
    required this.nameEn,
  });

  @override
  State<EditStationNameDialog> createState() => _EditStationNameDialogState();
}

class _EditStationNameDialogState extends State<EditStationNameDialog> {
  late TextEditingController _nCtrl;
  late TextEditingController _eCtrl;

  @override
  void initState() {
    super.initState();
    _nCtrl = TextEditingController(text: widget.name);
    _eCtrl = TextEditingController(text: widget.nameEn);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("編輯站點資訊", style: TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nCtrl,
            decoration: const InputDecoration(labelText: "中文名稱"),
          ),
          TextField(
            controller: _eCtrl,
            decoration: const InputDecoration(labelText: "英文名稱"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("取消"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'name': _nCtrl.text,
            'nameEn': _eCtrl.text,
          }),
          child: const Text("完成"),
        ),
      ],
    );
  }
}
