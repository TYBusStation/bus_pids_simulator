import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_route.dart';
import '../data/led_sequence.dart';
import '../data/status.dart';
import 'audio_manager.dart';
import 'tts.dart'
    if (dart.library.js_interop) 'tts_web.dart'
    if (dart.library.io) 'tts_stub.dart';

abstract class Static {
  static Map<String, List<BusRoute>> routeData = {};
  static Status currentStatus = Status.unknown;
  static final TTS = getTTS();
  static final audioManager = AudioManager();
  static const String _settingsBoxName = "settings_box";
  static late Box _box;

  static final ChangeNotifier settingsNotifier = ChangeNotifier();

  static double globalVolume = 0.7;
  static double globalSpeed = 1.0;
  static double arrivalDistance = 100.0;
  static double nextStationDistance = 250.0;
  static double nextStationDepartureDistance = 50.0;

  static List<String> stationVoiceSequence = [
    "{name_zh}",
    "{name_ho}",
    "{name_hk}",
    "{name_en}",
  ];
  static List<String> arrivalTemplate = ["{name}", "到了"];
  static List<String> nextStationTemplate = ["下一站", "{terminal}", "{name}"];
  static List<LedSequence> sloganList = [
    LedSequence(template: "搭車請招手、上車請刷卡、下車請按鈴"),
    LedSequence(template: "TPASS 2.0 常客優惠，月月領優惠回饋金"),
  ];
  static bool showStationListSlogan = true;
  static double ledScrollSpeed = 400.0;
  static double ledHeight = 150.0;

  static List<LedSequence> ledNextStationSeq = [
    LedSequence(template: "下一站"),
    LedSequence(template: "{terminal}"),
    LedSequence(template: "{name}"),
    LedSequence(template: "{nameEn}"),
  ];
  static List<LedSequence> ledArrivalSeq = [
    LedSequence(template: "{name}"),
    LedSequence(template: "{nameEn}"),
    LedSequence(template: "到了"),
  ];

  static void log(String message) =>
      print("[${DateTime.now().toIso8601String()}] $message");

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_settingsBoxName);
    await _loadSettings();
    await audioManager.init();
    await _loadRoutes();
    await TTS.init();
    await requestLocationPermission();
  }

  static Future<void> _loadSettings() async {
    globalVolume = _box.get('globalVolume', defaultValue: 0.7);
    globalSpeed = _box.get('globalSpeed', defaultValue: 1.0);
    arrivalDistance = _box.get('arrivalDistance', defaultValue: 100.0);
    nextStationDistance = _box.get('nextStationDistance', defaultValue: 250.0);
    nextStationDepartureDistance = _box.get(
      'nextStationDepartureDistance',
      defaultValue: 50.0,
    );
    stationVoiceSequence = List<String>.from(
      _box.get('stationVoiceSequence', defaultValue: stationVoiceSequence),
    );
    arrivalTemplate = List<String>.from(
      _box.get('arrivalTemplate', defaultValue: arrivalTemplate),
    );
    nextStationTemplate = List<String>.from(
      _box.get('nextStationTemplate', defaultValue: nextStationTemplate),
    );

    if (_box.containsKey('sloganList')) {
      sloganList = (jsonDecode(_box.get('sloganList')) as List)
          .map((e) => LedSequence.fromJson(e))
          .toList();
    }

    showStationListSlogan = _box.get(
      'showStationListSlogan',
      defaultValue: true,
    );
    ledScrollSpeed = _box.get('ledScrollSpeed', defaultValue: 400.0);
    ledHeight = _box.get('ledHeight', defaultValue: 150.0);

    if (_box.containsKey('ledNextStationSeq')) {
      ledNextStationSeq = (jsonDecode(_box.get('ledNextStationSeq')) as List)
          .map((e) => LedSequence.fromJson(e))
          .toList();
    }
    if (_box.containsKey('ledArrivalSeq')) {
      ledArrivalSeq = (jsonDecode(_box.get('ledArrivalSeq')) as List)
          .map((e) => LedSequence.fromJson(e))
          .toList();
    }
  }

  static Future<void> saveSettings() async {
    await _box.put('globalVolume', globalVolume);
    await _box.put('globalSpeed', globalSpeed);
    await _box.put('arrivalDistance', arrivalDistance);
    await _box.put('nextStationDistance', nextStationDistance);
    await _box.put(
      'nextStationDepartureDistance',
      nextStationDepartureDistance,
    );
    await _box.put('stationVoiceSequence', stationVoiceSequence);
    await _box.put('arrivalTemplate', arrivalTemplate);
    await _box.put('nextStationTemplate', nextStationTemplate);
    await _box.put(
      'sloganList',
      jsonEncode(sloganList.map((e) => e.toJson()).toList()),
    );
    await _box.put('showStationListSlogan', showStationListSlogan);
    await _box.put('ledScrollSpeed', ledScrollSpeed);
    await _box.put('ledHeight', ledHeight);
    await _box.put(
      'ledNextStationSeq',
      jsonEncode(ledNextStationSeq.map((e) => e.toJson()).toList()),
    );
    await _box.put(
      'ledArrivalSeq',
      jsonEncode(ledArrivalSeq.map((e) => e.toJson()).toList()),
    );
    settingsNotifier.notifyListeners();
  }

  static Future<bool> hasStationAudio(String stationId) async {
    try {
      await rootBundle.load("assets/audio/stations/$stationId.mp3");
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<String> getFilteredVoiceSequence(bool hasAudio) {
    if (!hasAudio) return stationVoiceSequence;
    return stationVoiceSequence
        .where(
          (s) =>
              s != "{name_zh}" &&
              s != "{name_ho}" &&
              s != "{name_hk}" &&
              s != "{name_en}",
        )
        .toList();
  }

  static Future<void> requestLocationPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied)
        p = await Geolocator.requestPermission();
    } catch (e) {
      log("Error: $e");
    }
  }

  static Future<void> _loadRoutes() async {
    for (var c in ["Taoyuan", "Taipei", "NewTaipei", "Taichung", "InterCity"]) {
      try {
        final d = await rootBundle.loadString("assets/routes/$c.json");
        routeData[c] = (jsonDecode(d) as List)
            .map((r) => BusRoute.fromJson(r))
            .toList();
      } catch (e) {
        log("Load failed $c: $e");
      }
    }
  }

  static List<LatLng> wktPrase(String wkt) =>
      RegExp(r"(-?\d+\.?\d*)\s+(-?\d+\.?\d*)")
          .allMatches(wkt)
          .map(
            (m) => LatLng(double.parse(m.group(2)!), double.parse(m.group(1)!)),
          )
          .toList();
}
