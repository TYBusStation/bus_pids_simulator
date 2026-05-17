import 'dart:async';

import 'package:bus_pids_simulator/data/status.dart';
import 'package:bus_pids_simulator/pages/settings_page.dart';
import 'package:bus_pids_simulator/utils/static.dart';
import 'package:bus_pids_simulator/utils/web_interop.dart'
    if (dart.library.js_interop) 'package:bus_pids_simulator/utils/web_interop_web.dart'
    if (dart.library.html) 'package:bus_pids_simulator/utils/web_interop_web.dart'
    if (dart.library.io) 'package:bus_pids_simulator/utils/web_interop_stub.dart';
import 'package:bus_pids_simulator/widgets/landscape_provider.dart';
import 'package:bus_pids_simulator/widgets/route_analysis_provider.dart';
import 'package:bus_pids_simulator/widgets/status_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../widgets/map_bottom_panel.dart';
import 'contact_page.dart';
import 'info_page.dart';
import 'led_page.dart';
import 'map_page.dart';

class MainPage extends StatefulWidget {
  final bool showBottomInfo;
  final VoidCallback onToggleBottomInfo;

  @override
  State<MainPage> createState() => _MainPageState();

  const MainPage({
    super.key,
    this.showBottomInfo = true,
    required this.onToggleBottomInfo,
  });
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;
  StreamSubscription? _eventSubscription;
  final GlobalKey<MapBottomPanelState> _bottomPanelKey = GlobalKey();

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
      label: '字幕',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined, size: 20),
      selectedIcon: Icon(Icons.settings, size: 20),
      label: '設定',
    ),
    NavigationDestination(
      icon: Icon(Icons.link_outlined, size: 20),
      selectedIcon: Icon(Icons.link, size: 20),
      label: '連結',
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
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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

  void _editLicensePlate() {
    final controller = TextEditingController(text: Static.licensePlate);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.directions_bus),
            SizedBox(width: 10),
            Text("設定車牌號碼"),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "車牌號碼"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              setState(() => Static.licensePlate = controller.text);
              Static.saveSettings();
              Navigator.pop(context);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  void _editDriverId() {
    final controller = TextEditingController(text: Static.driverId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.person), SizedBox(width: 10), Text("設定駕駛長編號")],
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "駕駛長編號"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              setState(() => Static.driverId = controller.text);
              Static.saveSettings();
              Navigator.pop(context);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<StatusChangeNotifier>().currentStatus;
    final analysis = context.watch<RouteAnalysisProvider>().currentAnalysis;
    final direction = status.direction;
    final route = status.route;

    final List<Widget> pages = [
      const InfoPage(),
      MapPage(
        key: const PageStorageKey('map_page_unique'),
        bottomPanelKey: _bottomPanelKey,
      ),
      const LedPage(),
      const SettingsPage(),
      const ContactPage(),
    ];

    return LandscapeProvider(
      builder: (context, landscape) {
        if (!landscape) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "請將螢幕打橫",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      getWebInterop().lockLandscape();
                    },
                    icon: const Icon(Icons.screen_rotation),
                    label: const Text("旋轉手機"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            toolbarHeight: 40,
            titleSpacing: 0,
            title: Row(
              children: [
                const SizedBox(width: 15),
                const Text(
                  "公車 PIDS 模擬器",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                InkWell(
                  onTap: _editLicensePlate,
                  child: Row(
                    children: [
                      const Icon(Icons.directions_bus, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        Static.licensePlate,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 30),
                InkWell(
                  onTap: _editDriverId,
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        Static.driverId,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
            actions: [
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
                SizedBox(
                  width: 60,
                  child: NavigationRail(
                    minWidth: 60,
                    selectedIndex: selectedIndex.clamp(
                      0,
                      _allDestinations.length - 1,
                    ),
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
                Expanded(
                  child: Stack(
                    children: [
                      IndexedStack(
                        index: selectedIndex.clamp(0, pages.length - 1),
                        children: pages,
                      ),
                      if (selectedIndex >= 1 &&
                          selectedIndex <= 2 &&
                          widget.showBottomInfo)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: MapBottomPanel(
                            key: _bottomPanelKey,
                            analysis: analysis,
                            stations: direction == Direction.go
                                ? route.stations.go
                                : route.stations.back,
                          ),
                        ),
                      if (selectedIndex >= 1 && selectedIndex <= 2)
                        Positioned(
                          bottom: widget.showBottomInfo ? 35 : 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: widget.onToggleBottomInfo,
                              child: Container(
                                width: 40,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                ),
                                child: Icon(
                                  widget.showBottomInfo
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                  color: Colors.white,
                                  size: 18,
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
