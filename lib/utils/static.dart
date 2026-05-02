import 'dart:convert';

import 'package:bus_pids_simulator/data/bus_route.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/status.dart';
import '../storage/local_storage.dart';

abstract class Static {
  static Future<void>? _initFuture;
  static final LocalStorage localStorage = LocalStorage();
  static List<BusRoute> routeData = [];
  static Status currentStatus = Status.unknown;

  static void log(String message) {
    print("[${DateTime.now().toIso8601String()}] $message");
  }

  static Future<void> init() async {
    await _loadRoutes();
    await requestLocationPermission();
  }

  static Future<void> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
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
          log("已載入 ${routeData.length} 條路線資料");
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
