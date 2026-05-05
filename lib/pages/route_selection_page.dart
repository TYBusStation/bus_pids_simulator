import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/bus_route.dart';
import '../data/status.dart';
import '../utils/formatter_utils.dart';
import '../utils/static.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class RouteSelectionPage extends StatefulWidget {
  const RouteSelectionPage({super.key});

  @override
  State<RouteSelectionPage> createState() => _RouteSelectionPageState();
}

class _RouteSelectionPageState extends State<RouteSelectionPage> {
  late BusRoute _selectedRoute;
  late Direction _selectedDirection;
  String _searchQuery = "";
  String _activeCityKey = 'taoyuan';
  List<BusRoute> _displayRoutes = [];
  final ScrollController _horizontalController = ScrollController();

  final Map<String, String> _cityNames = {
    'taoyuan': '桃園市',
    'taipei': '大臺北',
    'taichung': '臺中市',
  };

  @override
  void initState() {
    super.initState();
    _selectedRoute = Static.currentStatus.route;
    _selectedDirection = Static.currentStatus.direction;

    for (var entry in Static.routeData.entries) {
      if (entry.value.any(
        (r) => r.id == _selectedRoute.id && r.name == _selectedRoute.name,
      )) {
        _activeCityKey = entry.key;
        break;
      }
    }
    _performSearch();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchQuery.toLowerCase();
    final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

    final routes = Static.routeData[_activeCityKey] ?? [];
    final List<BusRoute> matchingRoutes = routes.where((route) {
      if (query.isEmpty) return true;
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

    matchingRoutes.sort((a, b) {
      bool isA = a.id == _selectedRoute.id && a.name == _selectedRoute.name;
      bool isB = b.id == _selectedRoute.id && b.name == _selectedRoute.name;
      if (isA) return -1;
      if (isB) return 1;
      return FormatterUtils.compareRoutes(a.name, b.name);
    });

    setState(() {
      _displayRoutes = matchingRoutes;
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
        toolbarHeight: 40,
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
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: SizedBox(
              height: 38,
              child: TextField(
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '搜尋 ${_cityNames[_activeCityKey]} 路線...',
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
              children: _cityNames.entries.map((e) {
                final isSelected = _activeCityKey == e.key;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _activeCityKey = e.key;
                      _performSearch();
                    });
                  },
                  child: Container(
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withOpacity(0.1)
                          : null,
                      border: isSelected
                          ? Border(
                              left: BorderSide(
                                color: colorScheme.primary,
                                width: 3,
                              ),
                            )
                          : null,
                    ),
                    child: Text(
                      e.value.split('').join('\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: AppScrollBehavior(),
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                thickness: 8,
                radius: const Radius.circular(4),
                child: ListView.builder(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  itemCount: _displayRoutes.length,
                  itemBuilder: (context, index) {
                    final route = _displayRoutes[index];
                    final isRouteSelected =
                        _selectedRoute.id == route.id &&
                        _selectedRoute.name == route.name;
                    return _buildRouteCard(
                      route,
                      isRouteSelected,
                      colorScheme,
                      theme,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(
    BusRoute route,
    bool isRouteSelected,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
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
                        color: colorScheme.primary,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'ID: ${route.id}',
                    style: TextStyle(fontSize: 11, color: colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildHorizontalStations(route),
              const SizedBox(height: 6),
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
              _buildCompactDirectionBtn(
                route,
                Direction.go,
                '往 ${route.destination}',
                isRouteSelected && _selectedDirection == Direction.go,
                colorScheme,
              ),
              const SizedBox(height: 4),
              _buildCompactDirectionBtn(
                route,
                Direction.back,
                '往 ${route.departure}',
                isRouteSelected && _selectedDirection == Direction.back,
                colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildCompactDirectionBtn(
    BusRoute route,
    Direction dir,
    String label,
    bool active,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () => _toggleSelection(route, dir),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? colorScheme.primary
              : colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: active ? Colors.white : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : colorScheme.onSurfaceVariant,
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
}
