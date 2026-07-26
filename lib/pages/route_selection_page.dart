import 'dart:async';
import 'dart:convert';

import 'package:bus_pids_simulator/pages/route_editor_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/bus_route.dart';
import '../data/status.dart';
import '../utils/formatter_utils.dart';
import '../utils/static.dart';

class RouteSelectionPage extends StatefulWidget {
  const RouteSelectionPage({super.key});

  @override
  State<RouteSelectionPage> createState() => _RouteSelectionPageState();
}

class _RouteSelectionPageState extends State<RouteSelectionPage> {
  late BusRoute _selectedRoute;
  late Direction _selectedDirection;
  String _searchQuery = "";
  String _activeCityKey = 'Custom';
  List<BusRoute> _displayRoutes = [];
  final ScrollController _horizontalController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _lastUpdatedInfo;
  bool _isDataExpired = false;

  @override
  void initState() {
    super.initState();
    _selectedRoute = Static.currentStatus.route;
    _selectedDirection = Static.currentStatus.direction;
    _loadCityFromCache(_activeCityKey);
    Static.fetchAvailableCities().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _loadCityFromCache(String key) {
    try {
      if (key == 'Custom') {
        _lastUpdatedInfo = null;
        _isDataExpired = false;
        _performSearch();
        return;
      }
      final cache = Static.getCityCache(key);
      if (cache != null) {
        final int ts = cache['timestamp'];
        final DateTime updateTime = DateTime.fromMillisecondsSinceEpoch(ts);
        _isDataExpired = DateTime.now().difference(updateTime).inDays >= 7;
        _lastUpdatedInfo = "${updateTime.month}/${updateTime.day}";

        final List<dynamic> data = jsonDecode(cache['data']);

        Static.routeData[key] = data.map((r) => BusRoute.fromJson(r)).toList();
      } else {
        Static.routeData[key] = [];
        _lastUpdatedInfo = null;
        _isDataExpired = false;
      }
    } catch (e) {
      print("解析城市 $key 出錯: $e");
      Static.routeData[key] = [];
      _lastUpdatedInfo = "資料損毀";
    }
    _performSearch();
  }

  void _onSearchChanged(String v) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = v;
      _performSearch();
    });
  }

  void _performSearch() {
    final query = _searchQuery.toLowerCase();
    final routes = Static.routeData[_activeCityKey] ?? [];
    _displayRoutes = routes.where((route) {
      final content =
          '${route.id} ${route.name} ${route.description} ${route.departure} ${route.destination}'
              .toLowerCase();
      return content.contains(query);
    }).toList();
    _displayRoutes.sort((a, b) => FormatterUtils.compareRoutes(a.name, b.name));
    if (mounted) setState(() {});
  }

  void _onCityTabTap(String key) {
    if (_isLoading) return;
    setState(() {
      _activeCityKey = key;
      _loadCityFromCache(key);
    });
  }

  Future<void> _fetchCityData() async {
    if (_activeCityKey == 'Custom' || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      print("正在請求: ${Static.API_BASE}/simulator_data?city=$_activeCityKey");

      final res = await Static.dio.get(
        "${Static.API_BASE}/simulator_data",
        queryParameters: {'city': _activeCityKey},
      );

      if (res.statusCode == 200) {
        final String rawJson = jsonEncode(res.data);
        await Static.saveCityData(_activeCityKey, rawJson);
        if (mounted) _loadCityFromCache(_activeCityKey);
        print("下載成功！");
      }
    } on DioException catch (e) {
      print("網路請求錯誤類型: ${e.type}");
      print("錯誤詳情: ${e.message}");
      if (mounted) FormatterUtils.showSnackbar(context, "更新失敗: ${e.type}");
    } catch (e) {
      print("其他錯誤: $e");
      if (mounted) FormatterUtils.showSnackbar(context, "系統錯誤");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(BusRoute route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("刪除路線"),
        content: Text("確定要刪除「${route.name}」嗎？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Static.deleteCustomRoute(route.id);
              Navigator.pop(ctx);
              _performSearch();
            },
            child: const Text("刪除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool hasData =
        Static.routeData.containsKey(_activeCityKey) &&
        Static.routeData[_activeCityKey]!.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 30,
        title: Text(
          '選擇路線 (當前：${_selectedRoute.name})',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          ElevatedButton.icon(
            label: const Text("確定", style: TextStyle(fontSize: 12)),
            onPressed: _isLoading
                ? null
                : () => Navigator.pop(
                    context,
                    Status(
                      route: _selectedRoute,
                      direction: _selectedDirection,
                      dutyStatus: DutyStatus.offDuty,
                    ),
                  ),
            icon: const Icon(Icons.check_circle, size: 16),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: SizedBox(
              height: 24,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: '搜尋...',
                  prefixIcon: const Icon(Icons.search, size: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: cs.surface,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.1),
                  border: Border(
                    right: BorderSide(
                      color: theme.dividerColor.withOpacity(0.08),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: Static.availableCities.length,
                        itemBuilder: (context, index) {
                          final key = Static.availableCities[index];
                          final isSelected = _activeCityKey == key;
                          return InkWell(
                            onTap: () => _onCityTabTap(key),
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primary.withOpacity(0.1)
                                    : null,
                                border: isSelected
                                    ? Border(
                                        left: BorderSide(
                                          color: cs.primary,
                                          width: 3,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Text(
                                key == 'Custom' ? '自定義' : key,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () => Static.fetchAvailableCities().then(
                        (_) => setState(() {}),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (!hasData && _activeCityKey != 'Custom')
                    ? _buildDownloadPrompt(cs)
                    : Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          itemCount:
                              _displayRoutes.length +
                              (_activeCityKey == 'Custom' ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _displayRoutes.length)
                              return _buildAddCard(cs);
                            return _buildRouteCard(
                              _displayRoutes[index],
                              cs,
                              theme,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (_activeCityKey != 'Custom' && hasData) _buildFloatingInfo(cs),
        ],
      ),
    );
  }

  Widget _buildFloatingInfo(ColorScheme cs) {
    return Positioned(
      bottom: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isDataExpired ? Colors.orange : cs.outline.withOpacity(0.2),
          ),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _lastUpdatedInfo != null ? "更新: $_lastUpdatedInfo" : "無紀錄",
              style: TextStyle(
                fontSize: 8,
                color: _isDataExpired ? Colors.orange : cs.outline,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 22,
              child: ElevatedButton(
                onPressed: _fetchCityData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text("更新", style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadPrompt(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storage_rounded,
            size: 48,
            color: cs.primary.withOpacity(0.2),
          ),
          const SizedBox(height: 8),
          Text(
            "尚未取得 $_activeCityKey 的資料",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchCityData,
            icon: const Icon(Icons.download, size: 18),
            label: const Text("取得資料"),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BusRoute route, ColorScheme cs, ThemeData theme) {
    bool isSel = _selectedRoute.id == route.id;
    bool isCustom = _activeCityKey == 'Custom';
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      child: Card(
        elevation: isSel ? 3 : 1,
        color: isSel ? cs.primaryContainer.withOpacity(0.3) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSel ? cs.primary : theme.dividerColor.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      route.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (val) {
                        if (val == 'copy') {
                          Static.saveCustomRoute(
                            route,
                          ).then((_) => _loadCityFromCache(_activeCityKey));
                          FormatterUtils.showSnackbar(context, "已複製到自定義");
                        } else if (val == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) =>
                                  RouteEditorPage(initialRoute: route),
                            ),
                          ).then((res) {
                            if (res == true) _loadCityFromCache(_activeCityKey);
                          });
                        } else if (val == 'delete') {
                          _confirmDelete(route);
                        }
                      },
                      itemBuilder: (context) => [
                        if (isCustom)
                          const PopupMenuItem(value: 'edit', child: Text("編輯")),
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text("複製到自定義"),
                        ),
                        if (isCustom)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              "刪除",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                'ID: ${route.id}',
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route.departure,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                  const Icon(Icons.circle, size: 8, color: Colors.red),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route.destination,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  route.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withOpacity(0.8),
                    height: 1.1,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),
              const Divider(height: 8),
              _buildCompactDirectionBtn(
                route,
                Direction.go,
                '往 ${route.destination}',
                isSel && _selectedDirection == Direction.go,
                cs,
              ),
              const SizedBox(height: 3),
              _buildCompactDirectionBtn(
                route,
                Direction.back,
                '往 ${route.departure}',
                isSel && _selectedDirection == Direction.back,
                cs,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDirectionBtn(
    BusRoute r,
    Direction d,
    String l,
    bool a,
    ColorScheme cs,
  ) {
    return InkWell(
      onTap: () => setState(() {
        _selectedRoute = r;
        _selectedDirection = d;
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: a ? cs.primary : cs.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              a ? Icons.check_circle : Icons.circle_outlined,
              size: 12,
              color: a ? Colors.white : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l,
                style: TextStyle(
                  color: a ? Colors.white : cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard(ColorScheme cs) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      child: InkWell(
        onTap: () =>
            Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const RouteEditorPage()),
            ).then((res) {
              if (res == true) _loadCityFromCache(_activeCityKey);
            }),
        child: Card(
          color: cs.primaryContainer.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 28, color: cs.primary),
              const SizedBox(height: 4),
              const Text(
                "新增",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
