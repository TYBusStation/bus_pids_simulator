import 'dart:async';

import 'package:bus_pids_simulator/data/status.dart';
import 'package:bus_pids_simulator/pages/settings_page.dart';
import 'package:bus_pids_simulator/utils/static.dart';
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
import 'lottie_page.dart';
import 'map_page.dart';

class MainPage extends StatefulWidget {
  final bool showBottomInfo;
  final VoidCallback onToggleBottomInfo;

  const MainPage({
    super.key,
    this.showBottomInfo = true,
    required this.onToggleBottomInfo,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;
  StreamSubscription? _eventSubscription;
  final GlobalKey<MapBottomPanelState> _bottomPanelKey = GlobalKey();

  static final List<NavigationDestination> _allDestinations = const [
    NavigationDestination(
      icon: Icon(Icons.info_outline, size: 18),
      selectedIcon: Icon(Icons.info, size: 18),
      label: '資訊',
    ),
    NavigationDestination(
      icon: Icon(Icons.map_outlined, size: 18),
      selectedIcon: Icon(Icons.map, size: 18),
      label: '地圖',
    ),
    NavigationDestination(
      icon: Icon(Icons.text_fields_outlined, size: 18),
      selectedIcon: Icon(Icons.text_fields, size: 18),
      label: '字幕',
    ),
    NavigationDestination(
      icon: Icon(Icons.print_outlined, size: 18),
      selectedIcon: Icon(Icons.print, size: 18),
      label: 'Lottie',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined, size: 18),
      selectedIcon: Icon(Icons.settings, size: 18),
      label: '設定',
    ),
    NavigationDestination(
      icon: Icon(Icons.link_outlined, size: 18),
      selectedIcon: Icon(Icons.link, size: 18),
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
                (selectedIndex == 0 || selectedIndex == 1))
              _showSpeedWarningDialog();
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
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text("警告", style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: const Text(
            "進站速度過快",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  void _editValue(String title, String current, Function(String) onSave) {
    final c = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        content: TextField(controller: c, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              onSave(c.text);
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
    return LandscapeProvider(
      builder: (context, landscape) {
        return Stack(
          children: [
            Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: widget.showBottomInfo
                  ? AppBar(
                      toolbarHeight: 32,
                      titleSpacing: 0,
                      title: Row(
                        children: [
                          const SizedBox(width: 30),
                          InkWell(
                            onTap: () =>
                                _editValue("設定車牌", Static.licensePlate, (v) {
                                  setState(() => Static.licensePlate = v);
                                  Static.saveSettings();
                                }),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_bus, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  Static.licensePlate,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          InkWell(
                            onTap: () =>
                                _editValue("設定駕駛編號", Static.driverId, (v) {
                                  setState(() => Static.driverId = v);
                                  Static.saveSettings();
                                }),
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  Static.driverId,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            "公車 PIDS 模擬器",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
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
                          const SizedBox(width: 30),
                        ],
                      ),
                    )
                  : null,
              body: SafeArea(
                child: Row(
                  children: [
                    if (widget.showBottomInfo)
                      SizedBox(
                        width: 50,
                        child: NavigationRail(
                          minWidth: 50,
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
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    if (widget.showBottomInfo)
                      const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: Stack(
                        children: [
                          IndexedStack(
                            index: selectedIndex,
                            children: [
                              const InfoPage(),
                              MapPage(
                                key: const PageStorageKey('map_page'),
                                bottomPanelKey: _bottomPanelKey,
                                isVisible: selectedIndex == 1,
                              ),
                              const LedPage(),
                              const LottiePage(),
                              const SettingsPage(),
                              const ContactPage(),
                            ],
                          ),
                          if (widget.showBottomInfo)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child:
                                  Consumer2<
                                    StatusChangeNotifier,
                                    RouteAnalysisProvider
                                  >(
                                    builder: (context, s, a, child) {
                                      final st = s.currentStatus;
                                      return MapBottomPanel(
                                        key: _bottomPanelKey,
                                        analysis: a.currentAnalysis,
                                        stations: st.direction == Direction.go
                                            ? st.route.stations.go
                                            : st.route.stations.back,
                                      );
                                    },
                                  ),
                            ),
                          Positioned(
                            bottom: widget.showBottomInfo ? 35 : 0,
                            left: 20,
                            child: GestureDetector(
                              onTap: widget.onToggleBottomInfo,
                              child: Container(
                                width: 48,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                                child: Icon(
                                  widget.showBottomInfo
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                  color: Colors.white,
                                  size: 32,
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
            ),
            if (!landscape)
              Positioned.fill(
                child: Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "請將螢幕打橫",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context
                              .read<LandscapeChangeNotifier>()
                              .toggleRotateAndFullscreen(),
                          icon: const Icon(Icons.screen_rotation),
                          label: const Text("旋轉螢幕"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
