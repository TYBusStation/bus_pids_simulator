import 'dart:convert';
import 'dart:typed_data';

import 'package:bus_pids_simulator/utils/setting_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_route.dart';
import '../data/status.dart';
import 'audio_manager.dart';
import 'tts_helper.dart';

abstract class Static {
  static const String API_BASE = "https://myster.freeddns.org:25566";

  // static const String API_BASE = "http://192.168.1.249:25567";
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
      debugPrint("開始初始化 Settings...");
      await settings.init();

      debugPrint("開始初始化 AudioManager...");
      await audioManager.init();

      debugPrint("開始初始化 TTS...");
      await TTS.init();

      await _loadCustomRoutes();
      await requestLocationPermission();
    } catch (e, stack) {
      debugPrint("❌ 初始化階段崩潰!");
      debugPrint("錯誤訊息: $e");
      debugPrint("堆疊追蹤: $stack");
      rethrow;
    }
  }

  static Future<void> _loadCustomRoutes() async {
    try {
      final box = await Hive.openBox("custom_routes_box");
      List<BusRoute> list = [];

      for (var k in box.keys) {
        final raw = box.get(k);
        if (raw == null) continue;

        try {
          String jsonStr;
          if (raw is Uint8List ||
              raw.runtimeType.toString().contains('Uint8List')) {
            jsonStr = utf8.decode(raw as Uint8List);
          } else {
            jsonStr = raw.toString();
          }

          final Map<String, dynamic> jsonData = jsonDecode(jsonStr);
          list.add(BusRoute.fromJson(jsonData));
        } catch (e) {
          debugPrint("解析自定義路線失敗 (Key: $k): $e, 資料型態: ${raw.runtimeType}");
        }
      }
      routeData['Custom'] = list;
      settings.notifyListeners();
    } catch (e) {
      debugPrint("載入自定義路線箱子失敗: $e");
    }
  }

  static Future<void> fetchAvailableCities() async {
    try {
      final res = await dio.get("$API_BASE/simulator_cities");
      if (res.statusCode == 200) {
        _serverCitiesCache = List<String>.from(res.data);
        final cityBox = await Hive.openBox("city_data_box");
        availableCities = {
          'Custom',
          ..._serverCitiesCache,
          ...cityBox.keys.map((e) => e.toString()),
        }.toList();
        settings.notifyListeners();
      }
    } catch (_) {}
  }

  static Future<void> saveCityData(String city, dynamic data) async {
    final cityBox = await Hive.openBox("city_data_box");
    String jsonRaw = data is String ? data : jsonEncode(data);
    await cityBox.put(city, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': jsonRaw,
    });
    await fetchAvailableCities();
  }

  static Map<String, dynamic>? getCityCache(String city) {
    try {
      if (!Hive.isBoxOpen("city_data_box")) return null;
      final cityBox = Hive.box("city_data_box");
      final entry = cityBox.get(city);

      if (entry == null) return null;

      if (entry is Uint8List ||
          entry.runtimeType.toString().contains('Uint8List')) {
        try {
          final decoded = jsonDecode(utf8.decode(entry as Uint8List));
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          } else {
            debugPrint(
              "CityCache $city 錯誤: 解碼後是 ${decoded.runtimeType} 而非 Map",
            );
            return null;
          }
        } catch (e) {
          debugPrint("CityCache $city 解碼失敗: $e");
          return null;
        }
      }

      if (entry is Map) {
        return Map<String, dynamic>.from(entry);
      }

      debugPrint("CityCache $city 讀取失敗: 預期為 Map, 但實際拿到 ${entry.runtimeType}");
      return null;
    } catch (e) {
      debugPrint("getCityCache (City: $city) 發生嚴重錯誤: $e");
      return null;
    }
  }

  static Future<void> saveCustomRoute(BusRoute route, {String? oldId}) async {
    final box = Hive.box("custom_routes_box");
    if (oldId != null && oldId != route.id) await box.delete("route_$oldId");
    await box.put("route_${route.id}", jsonEncode(route.toJson()));
    await _loadCustomRoutes();
  }

  static Future<void> deleteCustomRoute(String id) async {
    final box = Hive.box("custom_routes_box");
    await box.delete("route_$id");
    await _loadCustomRoutes();
  }

  static bool isCityLoaded(String key) {
    if (key == 'Custom') return true;
    try {
      return Hive.box("city_data_box").containsKey(key);
    } catch (_) {
      return false;
    }
  }

  static Future<void> refreshRoutes() async {
    await fetchAvailableCities();
    await _loadCustomRoutes();
  }

  static Future<void> saveSettings() => settings.save();

  static ChangeNotifier get settingsNotifier => settings;

  static List<LatLng> wktPrase(String wkt) =>
      RegExp(r"(-?\d+\.?\d*)\s+(-?\d+\.?\d*)")
          .allMatches(wkt)
          .map(
            (m) => LatLng(double.parse(m.group(2)!), double.parse(m.group(1)!)),
          )
          .toList();

  static Future<void> requestLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) await Geolocator.requestPermission();
  }
}
