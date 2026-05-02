import 'package:flutter/material.dart';

import '../data/bus_route.dart';
import '../data/status.dart';
import '../utils/formatter_utils.dart';
import '../utils/static.dart';
import '../widgets/searchable_list.dart';

class RouteSelectionPage extends StatefulWidget {
  const RouteSelectionPage({super.key});

  @override
  State<RouteSelectionPage> createState() => _RouteSelectionPageState();
}

class _RouteSelectionPageState extends State<RouteSelectionPage> {
  late BusRoute _selectedRoute;
  late Direction _selectedDirection;

  @override
  void initState() {
    super.initState();
    _selectedRoute = Static.currentStatus.route;
    _selectedDirection = Static.currentStatus.direction;
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
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '選擇路線 (當前：${Static.currentStatus.route.name}(${Static.currentStatus.route.id}) ${Static.currentStatus.route.description} | 往 ${Static.currentStatus.direction == Direction.go ? Static.currentStatus.route.destination : Static.currentStatus.route.departure})',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('確定'),
              onPressed: () => Navigator.pop(
                context,
                Status(
                  route: _selectedRoute,
                  direction: _selectedDirection,
                  dutyStatus: DutyStatus.offDuty,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SearchableList<BusRoute>(
        allItems: Static.routeData,
        searchHintText: '搜尋路線、描述或編號 (支援 Regex)',
        filterCondition: (route, text) {
          final content =
              '${route.id} ${route.name} ${route.description} ${route.departure} ${route.destination}';

          final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
          return tokens.every((token) {
            try {
              return RegExp(token, caseSensitive: false).hasMatch(content);
            } catch (_) {
              return content.toUpperCase().contains(token.toUpperCase());
            }
          });
        },
        sortCallback: (a, b) {
          if (_selectedRoute == a) return -1;
          if (_selectedRoute == b) return 1;
          return FormatterUtils.compareRoutes(a.name, b.name);
        },
        itemBuilder: (context, route) {
          final selection = _selectedRoute == route;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: selection
                ? colorScheme.primaryContainer.withOpacity(0.5)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.name,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.departure_board,
                        size: 18,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          route.departure,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Icon(Icons.arrow_forward, size: 16),
                      ),
                      const Icon(Icons.flag, size: 18, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          route.destination,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route.description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '編號：${route.id}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: Text(
                            '往 ${route.destination}',
                            style: textTheme.bodySmall,
                          ),
                          value:
                              selection && _selectedDirection == Direction.go,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) => value == true
                              ? _toggleSelection(route, Direction.go)
                              : _toggleSelection(
                                  BusRoute.unknown,
                                  Direction.go,
                                ),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: Text(
                            '往 ${route.departure}',
                            style: textTheme.bodySmall,
                          ),
                          value:
                              selection && _selectedDirection == Direction.back,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) => value == true
                              ? _toggleSelection(route, Direction.back)
                              : _toggleSelection(
                                  BusRoute.unknown,
                                  Direction.go,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        emptyStateWidget: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(height: 12),
              Text("找不到符合的路線", style: textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
