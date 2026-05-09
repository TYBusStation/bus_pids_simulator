import 'dart:async';

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
import 'led_page.dart';
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
  StreamSubscription? _eventSubscription;

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
      icon: Icon(Icons.text_fields_outlined, size: 20),
      selectedIcon: Icon(Icons.text_fields, size: 20),
      label: 'LED',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined, size: 20),
      selectedIcon: Icon(Icons.settings, size: 20),
      label: '設定',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _eventSubscription = context
          .read<RouteAnalysisProvider>()
          .eventStream
          .listen((event) {
            if (event == "SPEED_WARNING" &&
                (selectedIndex == 0 || selectedIndex == 1)) {
              _showSpeedWarningDialog();
            }
          });
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _showSpeedWarningDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        Timer(const Duration(seconds: 3), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
        return AlertDialog(
          backgroundColor: Colors.red.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 10),
              Text("警告", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            "進站速度過快",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "關閉",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LandscapeProvider(
      builder: (context, landscape) {
        if (!landscape) {
          return const Scaffold(
            resizeToAvoidBottomInset: false,
            body: Center(
              child: Text(
                "請將螢幕打橫",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            toolbarHeight: 40,
            titleSpacing: 15,
            title: const Text(
              "公車 PIDS 模擬器",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              Selector<StatusChangeNotifier, Status>(
                selector: (_, n) => n.currentStatus,
                builder: (context, status, _) {
                  final isOnDuty = status.dutyStatus == DutyStatus.onDuty;
                  final String dirText = status.direction == Direction.go
                      ? "去程"
                      : "返程";
                  final String destText = status.direction == Direction.go
                      ? status.route.destination
                      : status.route.departure;
                  return Row(
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
                          isOnDuty ? "營運中" : "非營運",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "${status.route.name} $dirText 往 $destText",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 10),
              Selector<LocationChangeNotifier, double>(
                selector: (_, n) => n.currentSpeed,
                builder: (context, speed, _) => Text(
                  "時速：${speed.toStringAsFixed(1)} km/h",
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Selector<LocationChangeNotifier, List<double?>>(
                selector: (_, n) => [
                  n.currentLocation?.latitude,
                  n.currentLocation?.longitude,
                ],
                builder: (context, loc, _) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      loc[0] != null
                          ? "緯度：${loc[0]!.toStringAsFixed(6)}"
                          : "緯度：未知",
                      style: const TextStyle(fontSize: 10, height: 1.2),
                    ),
                    Text(
                      loc[1] != null
                          ? "經度：${loc[1]!.toStringAsFixed(6)}"
                          : "經度：未知",
                      style: const TextStyle(fontSize: 10, height: 1.2),
                    ),
                  ],
                ),
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
          body: SafeArea(
            child: Row(
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
                  child: Stack(
                    children: [
                      IndexedStack(
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
                          const LedPage(),
                          const SettingsPage(),
                        ],
                      ),
                      if (selectedIndex == 1)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 0,
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
