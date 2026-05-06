import 'package:bus_pids_simulator/data/status.dart';
import 'package:bus_pids_simulator/pages/settings_page.dart';
import 'package:bus_pids_simulator/widgets/landscape_provider.dart';
import 'package:bus_pids_simulator/widgets/location_provider.dart';
import 'package:bus_pids_simulator/widgets/route_analysis_provider.dart';
import 'package:bus_pids_simulator/widgets/status_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'info_page.dart';
import 'map_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;
  bool _showNavBar = true;
  bool _showBottomInfo = true;

  static final List<NavigationDestination> _allDestinations = const [
    NavigationDestination(
      icon: Icon(Icons.info_outline, size: 20),
      selectedIcon: Icon(Icons.info, size: 20),
      label: '資訊',
    ),
    NavigationDestination(
      icon: Icon(Icons.map_outlined, size: 20),
      selectedIcon: Icon(Icons.map, size: 20),
      label: '地圖',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined, size: 20),
      selectedIcon: Icon(Icons.settings, size: 20),
      label: '設定',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LandscapeProvider(
      builder: (context, landscape) {
        if (!landscape) {
          return const Scaffold(
            body: Center(
              child: Text(
                "請將螢幕打橫",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        return Consumer2<LocationChangeNotifier, StatusChangeNotifier>(
          builder: (context, locNotifier, statusNotifier, child) {
            final status = statusNotifier.currentStatus;
            final location = locNotifier.currentLocation;
            final speed = locNotifier.currentSpeed;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<RouteAnalysisProvider>().update(
                location,
                speed,
                status,
              );
            });

            final bool isOnDuty = status.dutyStatus == DutyStatus.onDuty;
            final String dirText = status.direction == Direction.go
                ? "去程"
                : "返程";
            final String destText = status.direction == Direction.go
                ? status.route.destination
                : status.route.departure;
            final String routeString =
                "${status.route.name} $dirText 往 $destText";
            final String dutyText = isOnDuty ? "營運中" : "非營運";

            return Scaffold(
              appBar: AppBar(
                toolbarHeight: 40,
                titleSpacing: 15,
                title: const Text(
                  "公車 PIDS 模擬器",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                actions: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isOnDuty ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dutyText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        routeString,
                        style: const TextStyle(
                          fontSize: 14,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "時速：${speed.toStringAsFixed(1)} km/h",
                        style: const TextStyle(
                          fontSize: 14,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            location != null
                                ? "緯度：${location.latitude.toStringAsFixed(6)}"
                                : "緯度：未知",
                            style: const TextStyle(fontSize: 10, height: 1.2),
                          ),
                          Text(
                            location != null
                                ? "經度：${location.longitude.toStringAsFixed(6)}"
                                : "經度：未知",
                            style: const TextStyle(fontSize: 10, height: 1.2),
                          ),
                        ],
                      ),
                      const SizedBox(width: 15),
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(seconds: 1)),
                        builder: (context, snapshot) => Text(
                          DateFormat('HH:mm:ss').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                    ],
                  ),
                ],
              ),
              body: SafeArea(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        if (_showNavBar || selectedIndex != 1) ...[
                          SizedBox(
                            width: 60,
                            child: NavigationRail(
                              minWidth: 60,
                              selectedIndex: selectedIndex,
                              onDestinationSelected: (index) =>
                                  setState(() => selectedIndex = index),
                              labelType: NavigationRailLabelType.all,
                              destinations: _allDestinations
                                  .map(
                                    (d) => NavigationRailDestination(
                                      icon: d.icon,
                                      selectedIcon: d.selectedIcon,
                                      label: Text(
                                        d.label,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const VerticalDivider(thickness: 1, width: 1),
                        ],
                        Expanded(
                          child: IndexedStack(
                            index: selectedIndex,
                            children: [
                              const InfoPage(),
                              MapPage(
                                key: const PageStorageKey('map_page_unique'),
                                showBottomInfo: _showBottomInfo,
                                onToggleBottomInfo: () => setState(
                                  () => _showBottomInfo = !_showBottomInfo,
                                ),
                              ),
                              const SettingsPage(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (selectedIndex == 1) ...[
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: (_showNavBar) ? 61 : 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _showNavBar = !_showNavBar),
                            child: Container(
                              width: 20,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(10),
                                ),
                              ),
                              child: Icon(
                                _showNavBar
                                    ? Icons.keyboard_arrow_left
                                    : Icons.keyboard_arrow_right,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
