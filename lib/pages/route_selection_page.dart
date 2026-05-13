import 'dart:async';
import 'dart:convert';

import 'package:bus_pids_simulator/pages/route_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  String _activeCityKey = 'Taoyuan';
  List<BusRoute> _displayRoutes = [];
  final ScrollController _horizontalController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  final Map<String, String> _cityNames = {
    'Taoyuan': '桃園市',
    'Taipei': '臺北市',
    'NewTaipei': '新北市',
    'Taichung': '臺中市',
    'InterCity': '公路客運',
    'Custom': '自定義',
  };

  @override
  void initState() {
    super.initState();
    _selectedRoute = Static.currentStatus.route;
    _selectedDirection = Static.currentStatus.direction;
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
    setState(() {});
  }

  void _refreshList() {
    setState(() {
      _activeCityKey = 'Custom';
      _searchQuery = "";
      _searchCtrl.clear();
      _performSearch();
      final routes = Static.routeData['Custom'] ?? [];
      final idx = routes.indexWhere((r) => r.id == _selectedRoute.id);
      if (idx != -1) {
        _selectedRoute = routes[idx];
      }
    });
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
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: Text(
          '選擇路線 (當前：${_selectedRoute.name})',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          FilledButton.icon(
            label: const Text("確認"),
            onPressed: () => Navigator.pop(
              context,
              Status(
                route: _selectedRoute,
                direction: _selectedDirection,
                dutyStatus: DutyStatus.offDuty,
              ),
            ),
            icon: const Icon(Icons.check, size: 28),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '搜尋...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          Container(
            width: 60,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.2),
              border: Border(
                right: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
              ),
            ),
            child: ListView(
              children: _cityNames.entries
                  .map(
                    (e) => InkWell(
                      onTap: () {
                        setState(() {
                          _activeCityKey = e.key;
                          _performSearch();
                        });
                      },
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _activeCityKey == e.key
                              ? colorScheme.primary.withOpacity(0.1)
                              : null,
                          border: _activeCityKey == e.key
                              ? Border(
                                  left: BorderSide(
                                    color: colorScheme.primary,
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        child: Text(
                          e.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _activeCityKey == e.key
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _activeCityKey == e.key
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                itemCount: _displayRoutes.length + 1,
                itemBuilder: (context, index) {
                  if (index == _displayRoutes.length)
                    return _buildAddCard(colorScheme);
                  return _buildRouteCard(
                    _displayRoutes[index],
                    colorScheme,
                    theme,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BusRoute route, ColorScheme cs, ThemeData theme) {
    bool isSel = _selectedRoute.id == route.id;
    bool isCustom = _activeCityKey == 'Custom';
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      child: Card(
        elevation: isSel ? 4 : 1,
        color: isSel ? cs.primaryContainer.withOpacity(0.3) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSel ? cs.primary : theme.dividerColor.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (val) {
                      if (val == 'copy') {
                        Static.saveCustomRoute(
                          route,
                        ).then((_) => _refreshList());
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text("已複製")));
                      } else if (val == 'export') {
                        Clipboard.setData(
                          ClipboardData(text: jsonEncode(route.toJson())),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("JSON 已複製")),
                        );
                      } else if (val == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) =>
                                RouteEditorPage(initialRoute: route),
                          ),
                        ).then((res) {
                          if (res == true) _refreshList();
                        });
                      } else if (val == 'delete') {
                        _confirmDelete(route);
                      }
                    },
                    itemBuilder: (context) => [
                      if (isCustom)
                        const PopupMenuItem(value: 'edit', child: Text("編輯")),
                      const PopupMenuItem(value: 'copy', child: Text("複製")),
                      const PopupMenuItem(value: 'export', child: Text("匯出")),
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
                ],
              ),
              Text(
                'ID: ${route.id}',
                style: TextStyle(fontSize: 11, color: cs.outline),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route.departure,
                      style: const TextStyle(
                        fontSize: 13,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  route.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.8),
                    height: 1.2,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),
              const Divider(height: 12),
              _buildCompactDirectionBtn(
                route,
                Direction.go,
                '往 ${route.destination}',
                isSel && _selectedDirection == Direction.go,
                cs,
              ),
              const SizedBox(height: 4),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: a ? cs.primary : cs.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              a ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: a ? Colors.white : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l,
                style: TextStyle(
                  color: a ? Colors.white : cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
      width: 150,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      child: InkWell(
        onTap: () =>
            Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const RouteEditorPage()),
            ).then((res) {
              if (res == true) _refreshList();
            }),
        child: Card(
          color: cs.primaryContainer.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 32, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                "新增",
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
