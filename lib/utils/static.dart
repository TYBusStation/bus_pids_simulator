import 'dart:async';
import 'dart:convert';

import 'package:bus_pids_simulator/data/bus_route.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/status.dart';
import 'audio_manager.dart';
import 'tts.dart'
    if (dart.library.js_interop) 'tts_web.dart'
    if (dart.library.io) 'tts_stub.dart';

abstract class Static {
  static List<BusRoute> routeData = [];
  static Status currentStatus = Status.unknown;
  static final TTS = getTTS();
  static final audioManager = AudioManager();

  static double globalVolume = 0.5;
  static double globalSpeed = 1.0;

  static void log(String message) {
    print("[${DateTime.now().toIso8601String()}] $message");
  }

  static Future<void> init() async {
    await audioManager.init();
    await _loadRoutes();
    await TTS.init();
    await requestLocationPermission();
  }

  static Future<void> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        log("定位服務未開啟");
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
    } catch (e) {
      log("權限請求錯誤: $e");
    }
  }

  static Future<void> _loadRoutes() async {
    await rootBundle
        .loadString("assets/routes.json")
        .then((data) {
          List<dynamic> rawRouteData = jsonDecode(data);
          routeData = rawRouteData
              .map((rawRoute) => BusRoute.fromJson(rawRoute))
              .toList();
        })
        .catchError((e) {
          log("載入路線資料失敗: $e");
        });
  }

  static BusRoute getRouteById(String routeId) {
    return Static.routeData.firstWhere((r) => r.id == routeId);
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
