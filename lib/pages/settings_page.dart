import 'package:bus_pids_simulator/pages/audio_pack_page.dart';
import 'package:bus_pids_simulator/pages/gps_control_page.dart';
import 'package:bus_pids_simulator/pages/remote_audio_page.dart';
import 'package:bus_pids_simulator/pages/variable_setting_tab.dart';
import 'package:flutter/material.dart';

import 'audio_page.dart';
import 'led_setting_tab.dart';
import 'lottie_settings_tab.dart';
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
      length: 8,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: const SafeArea(
              bottom: false,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: EdgeInsets.symmetric(horizontal: 12),
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: TextStyle(fontSize: 13),
                indicatorWeight: 2,
                tabs: [
                  Tab(height: 38, text: "定位模式"),
                  Tab(height: 38, text: "報站規則"),
                  Tab(height: 38, text: "字幕設定"),
                  Tab(height: 38, text: "Lottie設定"),
                  Tab(height: 38, text: "顯示變數"),
                  Tab(height: 38, text: "單獨語音"),
                  Tab(height: 38, text: "語音包"),
                  Tab(height: 38, text: "遠端語音"),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            GpsControlPage(),
            RulesTab(),
            LedSettingsTab(),
            LottieSettingsTab(),
            VariableSettingTab(),
            AudioPage(),
            AudioPackPage(),
            RemoteAudioPage(),
          ],
        ),
      ),
    );
  }
}
