import 'package:bus_pids_simulator/pages/rules_tab.dart';
import 'package:flutter/material.dart';

import 'audio_page.dart';
import 'led_setting_tab.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: "報站規則"),
              Tab(text: "LED 設定"),
              Tab(text: "語音管理"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [RulesTab(), LedSettingsTab(), AudioPage()],
        ),
      ),
    );
  }
}
