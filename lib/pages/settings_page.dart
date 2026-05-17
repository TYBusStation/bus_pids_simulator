import 'package:bus_pids_simulator/pages/audio_pack_page.dart';
import 'package:bus_pids_simulator/pages/gps_control_page.dart';
import 'package:flutter/material.dart';

import 'audio_page.dart';
import 'led_setting_tab.dart';
import 'rules_tab.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: "定位模式"),
              Tab(text: "報站規則"),
              Tab(text: "字幕設定"),
              Tab(text: "單獨語音"),
              Tab(text: "語音包"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            GpsControlPage(),
            RulesTab(),
            LedSettingsTab(),
            AudioPage(),
            AudioPackPage(),
          ],
        ),
      ),
    );
  }
}
