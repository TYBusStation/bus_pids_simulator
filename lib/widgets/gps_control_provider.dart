import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_route.dart';
import '../data/status.dart';
import '../utils/static.dart';
import '../widgets/location_provider.dart';

class GpsControlProvider extends ChangeNotifier {
  Timer? _simTimer;
  bool _isSimulating = false;
  double _simSpeedKmh = 40.0;
  int _updateIntervalMs = 500;
  BusRoute? _simRoute;
  Direction _simDirection = Direction.go;
  int _currentPathIndex = 0;
  double _segmentProgress = 0.0;

  bool get isSimulating => _isSimulating;

  double get simSpeedKmh => _simSpeedKmh;

  int get updateIntervalMs => _updateIntervalMs;

  BusRoute? get simRoute => _simRoute;

  Direction get simDirection => _simDirection;

  void setSimRoute(BusRoute route, Direction dir) {
    _simRoute = route;
    _simDirection = dir;
    _currentPathIndex = 0;
    _segmentProgress = 0.0;
    notifyListeners();
  }

  void setSimSpeed(double speed) {
    _simSpeedKmh = speed;
    notifyListeners();
  }

  void jumpToStation(int stationIndex, LocationChangeNotifier locNotifier) {
    if (_simRoute == null) return;
    final stations = _simDirection == Direction.go
        ? _simRoute!.stations.go
        : _simRoute!.stations.back;
    final points = _simDirection == Direction.go
        ? _simRoute!.path.goPoints
        : _simRoute!.path.backPoints;
    if (stationIndex < 0 || stationIndex >= stations.length || points.isEmpty)
      return;

    if (stationIndex == 0) {
      _currentPathIndex = 0;
      _segmentProgress = 0.0;
      locNotifier.updateManualLocation(points[0], _simSpeedKmh);
      notifyListeners();
      return;
    }

    final prevStation = stations[stationIndex - 1];
    final LatLng sPos = LatLng(prevStation.lat, prevStation.lon);

    int bestSegmentIndex = 0;
    double minDistance = double.infinity;
    double bestT = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final double dx = p2.longitude - p1.longitude;
      final double dy = p2.latitude - p1.latitude;
      if (dx == 0 && dy == 0) continue;

      double t =
          ((sPos.longitude - p1.longitude) * dx +
              (sPos.latitude - p1.latitude) * dy) /
          (dx * dx + dy * dy);
      t = t.clamp(0.0, 1.0);

      final double projLon = p1.longitude + t * dx;
      final double projLat = p1.latitude + t * dy;

      final double dist = const Distance().as(
        LengthUnit.Meter,
        sPos,
        LatLng(projLat, projLon),
      );
      if (dist < minDistance) {
        minDistance = dist;
        bestSegmentIndex = i;
        bestT = t;
      }
    }

    double remainingOffset = Static.nextStationDepartureDistance + 1.0;
    int currentIndex = bestSegmentIndex;
    double currentT = bestT;

    while (remainingOffset > 0 && currentIndex < points.length - 1) {
      final p1 = points[currentIndex];
      final p2 = points[currentIndex + 1];
      final double segDist = const Distance().as(LengthUnit.Meter, p1, p2);
      final double distFromCurrentT = segDist * (1.0 - currentT);

      if (distFromCurrentT <= remainingOffset) {
        remainingOffset -= distFromCurrentT;
        currentIndex++;
        currentT = 0.0;
      } else {
        currentT += (remainingOffset / segDist);
        remainingOffset = 0;
      }
    }

    if (currentIndex >= points.length - 1) {
      currentIndex = points.length - 2;
      currentT = 1.0;
    }

    _currentPathIndex = currentIndex;
    _segmentProgress = currentT;

    final pStart = points[_currentPathIndex];
    final pEnd = points[_currentPathIndex + 1];
    final double finalLat =
        pStart.latitude + (pEnd.latitude - pStart.latitude) * _segmentProgress;
    final double finalLon =
        pStart.longitude +
        (pEnd.longitude - pStart.longitude) * _segmentProgress;

    locNotifier.updateManualLocation(LatLng(finalLat, finalLon), _simSpeedKmh);
    notifyListeners();
  }

  void toggleSimulation(LocationChangeNotifier locNotifier) {
    if (_isSimulating) {
      _stopSim();
    } else {
      if (_simRoute == null) return;
      _isSimulating = true;
      _startSimLoop(locNotifier);
    }
    notifyListeners();
  }

  void _stopSim() {
    _simTimer?.cancel();
    _isSimulating = false;
  }

  void _startSimLoop(LocationChangeNotifier locNotifier) {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(Duration(milliseconds: _updateIntervalMs), (
      timer,
    ) {
      if (locNotifier.gpsMode != GpsMode.manual || _simRoute == null) {
        _stopSim();
        notifyListeners();
        return;
      }
      final points = _simDirection == Direction.go
          ? _simRoute!.path.goPoints
          : _simRoute!.path.backPoints;
      if (points.length < 2) return;

      if (_currentPathIndex >= points.length - 1) {
        _currentPathIndex = 0;
        _segmentProgress = 0.0;
      }

      LatLng p1 = points[_currentPathIndex];
      LatLng p2 = points[_currentPathIndex + 1];
      final distance = const Distance().as(LengthUnit.Meter, p1, p2);

      if (distance <= 0) {
        _currentPathIndex++;
        if (_currentPathIndex >= points.length - 1) _currentPathIndex = 0;
        return;
      }

      double step = (_simSpeedKmh / 3.6) * (_updateIntervalMs / 1000.0);
      _segmentProgress += (step / distance);

      while (_segmentProgress >= 1.0) {
        double overshotDist = (_segmentProgress - 1.0) * distance;
        _currentPathIndex++;
        if (_currentPathIndex >= points.length - 1) {
          _currentPathIndex = 0;
          _segmentProgress = 0.0;
          break;
        }
        p1 = points[_currentPathIndex];
        p2 = points[_currentPathIndex + 1];
        double nextDist = const Distance().as(LengthUnit.Meter, p1, p2);
        if (nextDist > 0) {
          _segmentProgress = overshotDist / nextDist;
          break;
        } else {
          _segmentProgress = 1.0;
        }
      }

      final double lat =
          points[_currentPathIndex].latitude +
          (points[_currentPathIndex + 1].latitude -
                  points[_currentPathIndex].latitude) *
              _segmentProgress;
      final double lon =
          points[_currentPathIndex].longitude +
          (points[_currentPathIndex + 1].longitude -
                  points[_currentPathIndex].longitude) *
              _segmentProgress;
      locNotifier.updateManualLocation(LatLng(lat, lon), _simSpeedKmh);
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }
}
