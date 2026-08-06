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
  int _updateIntervalMs = 1000;
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
    final points = _simDirection == Direction.go
        ? _simRoute!.path.goPoints
        : _simRoute!.path.backPoints;
    final stations = _simDirection == Direction.go
        ? _simRoute!.stations.go
        : _simRoute!.stations.back;
    if (stationIndex < 0 || stationIndex >= stations.length || points.isEmpty)
      return;

    if (stationIndex == 0) {
      _currentPathIndex = 0;
      _segmentProgress = 0.0;
      locNotifier.updateManualLocation(points[0], _simSpeedKmh, force: true);
      return;
    }

    final sPos = LatLng(
      stations[stationIndex - 1].lat,
      stations[stationIndex - 1].lon,
    );
    final distanceUtil = const Distance();
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
      final double dist = distanceUtil.as(
        LengthUnit.Meter,
        sPos,
        LatLng(
          p1.latitude + t * (p2.latitude - p1.latitude),
          p1.longitude + t * dx,
        ),
      );
      if (dist < minDistance) {
        minDistance = dist;
        bestSegmentIndex = i;
        bestT = t;
      }
    }

    double remainingOffset = Static.settings.nextStationDepartureDistance + 5.0;
    int currentIndex = bestSegmentIndex;
    double currentT = bestT;
    while (remainingOffset > 0 && currentIndex < points.length - 1) {
      final d = distanceUtil.as(
        LengthUnit.Meter,
        points[currentIndex],
        points[currentIndex + 1],
      );
      final canMove = d * (1.0 - currentT);
      if (canMove <= remainingOffset) {
        remainingOffset -= canMove;
        currentIndex++;
        currentT = 0.0;
      } else {
        currentT += (remainingOffset / d);
        remainingOffset = 0;
      }
    }

    _currentPathIndex = currentIndex.clamp(0, points.length - 2);
    _segmentProgress = currentT.clamp(0.0, 1.0);
    final pStart = points[_currentPathIndex];
    final pEnd = points[_currentPathIndex + 1];
    locNotifier.updateManualLocation(
      LatLng(
        pStart.latitude + (pEnd.latitude - pStart.latitude) * _segmentProgress,
        pStart.longitude +
            (pEnd.longitude - pStart.longitude) * _segmentProgress,
      ),
      _simSpeedKmh,
      force: true,
    );
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
    final distanceUtil = const Distance();
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
      double step = (_simSpeedKmh / 3.6) * (_updateIntervalMs / 1000.0);
      while (step > 0) {
        if (_currentPathIndex >= points.length - 1) {
          _currentPathIndex = 0;
          _segmentProgress = 0.0;
          break;
        }
        final p1 = points[_currentPathIndex];
        final p2 = points[_currentPathIndex + 1];
        final dist = distanceUtil.as(LengthUnit.Meter, p1, p2);
        if (dist <= 0) {
          _currentPathIndex++;
          continue;
        }
        double remainingInSeg = dist * (1.0 - _segmentProgress);
        if (step >= remainingInSeg) {
          step -= remainingInSeg;
          _currentPathIndex++;
          _segmentProgress = 0.0;
        } else {
          _segmentProgress += (step / dist);
          step = 0;
        }
      }
      final idx = _currentPathIndex.clamp(0, points.length - 2);
      final lat =
          points[idx].latitude +
          (points[idx + 1].latitude - points[idx].latitude) * _segmentProgress;
      final lon =
          points[idx].longitude +
          (points[idx + 1].longitude - points[idx].longitude) *
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
