import 'package:bus_pids_simulator/pages/settings_page.dart';
import 'package:bus_pids_simulator/widgets/landscape_provider.dart';
import 'package:flutter/material.dart';

import 'info_page.dart';
import 'map_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;

  static final List<NavigationDestination> _allDestinations = const [
    NavigationDestination(
      icon: Icon(Icons.info_outline),
      selectedIcon: Icon(Icons.info),
      label: '資訊',
    ),
    NavigationDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: '地圖',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: '設定',
    ),
  ];

  static final List<Widget Function()> _pageBuilders = [
    () => const InfoPage(),
    () => const MapPage(),
    () => const SettingsPage(),
  ];
  static final List<String> _appBarTitles = const ["公車 PIDS 模擬器", "即時地圖", "設定"];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (selectedIndex >= _allDestinations.length) {
      selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LandscapeProvider(
      builder: (context, landscape) => Scaffold(
        appBar: AppBar(title: Text(_appBarTitles[selectedIndex])),
        body: landscape
            ? _buildLandscapeLayout()
            : _pageBuilders[selectedIndex](),
        bottomNavigationBar: landscape
            ? null
            : NavigationBar(
                onDestinationSelected: (index) =>
                    setState(() => selectedIndex = index),
                selectedIndex: selectedIndex,
                destinations: _allDestinations,
              ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          destinations: _allDestinations.map((dest) {
            return NavigationRailDestination(
              icon: dest.icon,
              selectedIcon: dest.selectedIcon,
              label: Text(dest.label),
            );
          }).toList(),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: _pageBuilders[selectedIndex]()),
      ],
    );
  }
}
