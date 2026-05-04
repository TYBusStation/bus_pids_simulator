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
  List<BusRoute> _displayRoutes = [];
  List<BusRoute> _filteredRoutes = [];

  @override
  void initState() {
    super.initState();
    _selectedRoute = Static.currentStatus.route;
    _selectedDirection = Static.currentStatus.direction;

    // 初始化列表並執行一次排序
    _displayRoutes = List.from(Static.routeData);
    _displayRoutes.sort((a, b) {
      if (_selectedRoute == a) return -1;
      if (_selectedRoute == b) return 1;
      return FormatterUtils.compareRoutes(a.name, b.name);
    });
    _performSearch();
  }

  void _performSearch() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredRoutes = List.from(_displayRoutes);
      } else {
        final query = _searchQuery.toLowerCase();
        final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

        _filteredRoutes = _displayRoutes.where((route) {
          final content =
              '${route.id} ${route.name} ${route.description} ${route.departure} ${route.destination}'
                  .toLowerCase();
          return tokens.every((token) {
            try {
              return RegExp(token).hasMatch(content);
            } catch (_) {
              return content.contains(token);
            }
          });
        }).toList();
      }
    });
  }

  void _toggleSelection(BusRoute route, Direction direction) {
    setState(() {
      _selectedRoute = route;
      _selectedDirection = direction;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40, // 壓縮標題列高度
        title: Text(
          '選擇路線 (當前：${_selectedRoute.name})',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(
              context,
              Status(
                route: _selectedRoute,
                direction: _selectedDirection,
                dutyStatus: DutyStatus.offDuty,
              ),
            ),
            icon: const Icon(Icons.check_circle, size: 28),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44), // 壓縮搜尋列高度
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: SizedBox(
              height: 38,
              child: TextField(
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '搜尋路線、描述或編號...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: (v) {
                  _searchQuery = v;
                  _performSearch();
                },
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        itemCount: _filteredRoutes.length,
        itemBuilder: (context, index) {
          final route = _filteredRoutes[index];
          final isRouteSelected = _selectedRoute == route;

          return Container(
            width: 260, // 稍微縮小寬度
            margin: const EdgeInsets.only(right: 10),
            child: Card(
              elevation: isRouteSelected ? 4 : 1,
              color: isRouteSelected
                  ? colorScheme.primaryContainer.withOpacity(0.3)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isRouteSelected
                      ? colorScheme.primary
                      : theme.dividerColor.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 標題與編號列
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            route.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '編號：${route.id}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 2. 起訖點 (改為橫排)
                    _buildHorizontalStations(route),

                    const SizedBox(height: 6),

                    // 3. 描述 (壓縮間距與字級)
                    Expanded(
                      child: Text(
                        route.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.8),
                          height: 1.2,
                        ),
                        overflow: TextOverflow.fade,
                      ),
                    ),

                    const Divider(height: 12),

                    // 4. 方向按鈕 (緊湊化，文字恆白)
                    _buildCompactDirectionBtn(
                      route,
                      Direction.go,
                      '往 ${route.destination}',
                      isRouteSelected && _selectedDirection == Direction.go,
                    ),
                    const SizedBox(height: 4),
                    _buildCompactDirectionBtn(
                      route,
                      Direction.back,
                      '往 ${route.departure}',
                      isRouteSelected && _selectedDirection == Direction.back,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 橫式車站列組件
  Widget _buildHorizontalStations(BusRoute route) {
    const textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    );
    return Row(
      children: [
        const Icon(Icons.circle, size: 8, color: Colors.green),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            route.departure,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
        ),
        const Icon(Icons.circle, size: 8, color: Colors.red),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            route.destination,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 緊湊版方向按鈕
  Widget _buildCompactDirectionBtn(
    BusRoute route,
    Direction dir,
    String label,
    bool active,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _toggleSelection(route, dir),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
