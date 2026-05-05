import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_route.dart';
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

  static double globalVolume = 0.5;
  static double globalSpeed = 1.0;
  static double arrivalDistance = 100.0;
  static double nextStationDistance = 250.0;
  static double nextStationDepartureDistance = 50.0;

  static List<String> arrivalTemplate = ["{terminal}", "{name}", "到了"];
  static List<String> nextStationTemplate = ["下一站", "{terminal}", "{name}"];

  static void log(String message) {
    print("[${DateTime.now().toIso8601String()}] $message");
  }

  static Future<void> init() async {
    await Hive.initFlutter();
    await _loadSettings();
    await audioManager.init();
    await _loadRoutes();
    await TTS.init();
    await requestLocationPermission();
  }

  static Future<void> _loadSettings() async {
    _box = await Hive.openBox(_settingsBoxName);
    globalVolume = _box.get('globalVolume', defaultValue: 0.5);
    globalSpeed = _box.get('globalSpeed', defaultValue: 1.0);
    arrivalDistance = _box.get('arrivalDistance', defaultValue: 100.0);
    nextStationDistance = _box.get('nextStationDistance', defaultValue: 250.0);
    nextStationDepartureDistance = _box.get(
      'nextStationDepartureDistance',
      defaultValue: 50.0,
    );
    arrivalTemplate = List<String>.from(
      _box.get('arrivalTemplate', defaultValue: arrivalTemplate),
    );
    nextStationTemplate = List<String>.from(
      _box.get('nextStationTemplate', defaultValue: nextStationTemplate),
    );
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
    await _box.put('arrivalTemplate', arrivalTemplate);
    await _box.put('nextStationTemplate', nextStationTemplate);
  }

  static Future<void> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
    } catch (e) {
      log("Error: $e");
    }
  }

  static Future<void> _loadRoutes() async {
    await _loadRoute("taoyuan");
    await _loadRoute("taipei");
    await _loadRoute("taichung");
  }

  static Future<void> _loadRoute(String city) async {
    try {
      final data = await rootBundle.loadString("assets/routes/$city.json");
      List<dynamic> rawRouteData = jsonDecode(data);
      routeData[city] = rawRouteData
          .map((rawRoute) => BusRoute.fromJson(rawRoute))
          .toList();
    } catch (e, stacktrace) {
      log("Load failed: $e\n$stacktrace");
    }
  }

  static List<LatLng> wktPrase(String wkt) {
    final regExp = RegExp(r"(-?\d+\.?\d*)\s+(-?\d+\.?\d*)");
    final matches = regExp.allMatches(wkt);
    return matches.map((m) {
      double lng = double.parse(m.group(1)!);
      double lat = double.parse(m.group(2)!);
      return LatLng(lat, lng);
    }).toList();
  }
}
