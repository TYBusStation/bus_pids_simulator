import 'dart:convert';

import 'package:bus_pids_simulator/utils/setting_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_route.dart';
import '../data/status.dart';
import 'audio_manager.dart';
import 'tts_helper.dart';

abstract class Static {
  static const String API_BASE = "https://myster.freeddns.org:25566";
  static final Dio dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 120)),
  );
  static final SettingsService settings = SettingsService();
  static final audioManager = AudioManager();
  static final TTS = getTTS();
  static Status currentStatus = Status.unknown;
  static Map<String, List<BusRoute>> routeData = {};
  static List<String> availableCities = ['Custom'];
  static List<String> _serverCitiesCache = [];

  static Future<void> init() async {
    try {
      await settings.init();
      await loadAllFonts();
      await audioManager.init();
      await TTS.init();
      await _loadCustomRoutes();
      await fetchAvailableCities();
      await requestLocationPermission();
    } catch (e, stack) {
      debugPrint("Init Error: $e");
      rethrow;
    }
  }

  static Future<void> registerFont(String name, Uint8List bytes) async {
    try {
      final fontLoader = FontLoader(name);
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();
      debugPrint("[Font] Successfully registered: $name");
    } catch (e) {
      debugPrint("[Font] Failed to register $name: $e");
    }
  }

  static Future<void> loadAllFonts() async {
    for (var f in settings.fontList) {
      if (f.type == 'custom' && f.data != null) {
        await registerFont(f.name, f.data!);
      }
    }
    await GoogleFonts.pendingFonts([
      GoogleFonts.notoSansTc(fontWeight: FontWeight.w400),
      GoogleFonts.notoSansTc(fontWeight: FontWeight.w500),
      GoogleFonts.notoSansTc(fontWeight: FontWeight.w700),
    ]);
  }

  static Future<void> _loadCustomRoutes() async {
    try {
      final box = await Hive.openBox("custom_routes_box");
      List<BusRoute> list = [];
      for (var k in box.keys) {
        final raw = box.get(k);
        if (raw == null) continue;
        try {
          final String jsonStr = (raw is Uint8List)
              ? utf8.decode(raw)
              : raw.toString();
          list.add(BusRoute.fromJson(jsonDecode(jsonStr)));
        } catch (_) {}
      }
      routeData['Custom'] = list;
      settings.notifyListeners();
    } catch (_) {}
  }

  static Future<void> fetchAvailableCities() async {
    try {
      final cityBox = await Hive.openBox("city_data_box");
      final localCities = cityBox.keys.map((e) => e.toString()).toList();
      availableCities = {
        'Custom',
        ..._serverCitiesCache,
        ...localCities,
      }.toList();
      settings.notifyListeners();
      final res = await dio.get("$API_BASE/simulator_cities");
      if (res.statusCode == 200 && res.data != null) {
        if (res.data is List) {
          _serverCitiesCache = List<String>.from(res.data);
        }
        availableCities = {
          'Custom',
          ..._serverCitiesCache,
          ...localCities,
        }.toList();
        settings.notifyListeners();
      }
    } catch (_) {}
  }

  static Future<void> saveCityData(String city, dynamic data) async {
    final cityBox = await Hive.openBox("city_data_box");
    final jsonRaw = data is String ? data : jsonEncode(data);
    await cityBox.put(city, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': jsonRaw,
    });
    await fetchAvailableCities();
  }

  static Map<String, dynamic>? getCityCache(String city) {
    try {
      if (!Hive.isBoxOpen("city_data_box")) return null;
      final entry = Hive.box("city_data_box").get(city);
      if (entry == null) return null;
      if (entry is Uint8List) {
        final decoded = jsonDecode(utf8.decode(entry));
        return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      }
      if (entry is Map) return Map<String, dynamic>.from(entry);
    } catch (_) {}
    return null;
  }

  static Future<void> saveCustomRoute(BusRoute route, {String? oldId}) async {
    final box = Hive.box("custom_routes_box");
    if (oldId != null && oldId != route.id) await box.delete("route_$oldId");
    await box.put("route_${route.id}", jsonEncode(route.toJson()));
    await _loadCustomRoutes();
  }

  static Future<void> deleteCustomRoute(String id) async {
    await Hive.box("custom_routes_box").delete("route_$id");
    await _loadCustomRoutes();
  }

  static bool isCityLoaded(String key) =>
      (key == 'Custom') ? true : Hive.box("city_data_box").containsKey(key);

  static Future<void> refreshRoutes() async {
    await fetchAvailableCities();
    await _loadCustomRoutes();
  }

  static Future<void> saveSettings() => settings.save();

  static List<LatLng> wktPrase(String wkt) =>
      RegExp(r"(-?\d+\.?\d*)\s+(-?\d+\.?\d*)")
          .allMatches(wkt)
          .map(
            (m) => LatLng(double.parse(m.group(2)!), double.parse(m.group(1)!)),
          )
          .toList();

  static Future<void> requestLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    if (await Geolocator.checkPermission() == LocationPermission.denied)
      await Geolocator.requestPermission();
  }
}
