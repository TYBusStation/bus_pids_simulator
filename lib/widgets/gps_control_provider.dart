import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_route.dart';
import '../data/status.dart';
import '../utils/static.dart';
import 'location_provider.dart';

class GpsControlProvider extends ChangeNotifier {
  Timer? _simTimer;
  bool _isSimulating = false;
  double _simSpeedKmh = 40.0;
  int _updateIntervalMs = 1000;
  BusRoute? _simRoute;
  Direction _simDirection = Direction.go;
  int _currentPathIndex = 0;
  double _segmentProgress = 0.0;
  final Distance _distanceUtil = const Distance();

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

  Map<String, dynamic> _findNearestPointOnPath(
    LatLng targetPos,
    List<LatLng> points,
  ) {
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
          ((targetPos.longitude - p1.longitude) * dx +
              (targetPos.latitude - p1.latitude) * dy) /
          (dx * dx + dy * dy);
      t = t.clamp(0.0, 1.0);
      final double dist = _distanceUtil.as(
        LengthUnit.Meter,
        targetPos,
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
    return {'index': bestSegmentIndex, 't': bestT};
  }

  void _moveLocationByDistance(
    double offsetMeter,
    List<LatLng> points,
    LocationChangeNotifier locNotifier,
  ) {
    double remaining = offsetMeter.abs();
    bool forward = offsetMeter >= 0;

    while (remaining > 0) {
      final p1 = points[_currentPathIndex];
      final p2 = points[_currentPathIndex + 1];
      final segmentDist = _distanceUtil.as(LengthUnit.Meter, p1, p2);

      if (forward) {
        double canMove = segmentDist * (1.0 - _segmentProgress);
        if (canMove <= remaining) {
          if (_currentPathIndex >= points.length - 2) {
            _segmentProgress = 1.0;
            remaining = 0;
          } else {
            remaining -= canMove;
            _currentPathIndex++;
            _segmentProgress = 0.0;
          }
        } else {
          _segmentProgress += (remaining / segmentDist);
          remaining = 0;
        }
      } else {
        double canMove = segmentDist * _segmentProgress;
        if (canMove <= remaining) {
          if (_currentPathIndex <= 0) {
            _segmentProgress = 0.0;
            remaining = 0;
          } else {
            remaining -= canMove;
            _currentPathIndex--;
            _segmentProgress = 1.0;
          }
        } else {
          _segmentProgress -= (remaining / segmentDist);
          remaining = 0;
        }
      }
    }

    final idx = _currentPathIndex.clamp(0, points.length - 2);
    final pStart = points[idx];
    final pEnd = points[idx + 1];
    final bearing = _distanceUtil.bearing(pStart, pEnd);

    locNotifier.updateManualLocation(
      LatLng(
        pStart.latitude + (pEnd.latitude - pStart.latitude) * _segmentProgress,
        pStart.longitude +
            (pEnd.longitude - pStart.longitude) * _segmentProgress,
      ),
      _simSpeedKmh,
      heading: (bearing + 360) % 360,
      force: true,
    );
  }

  void jumpToNextStationTrigger(
    int stationIndex,
    LocationChangeNotifier locNotifier,
  ) {
    if (_simRoute == null) return;
    final points = _simDirection == Direction.go
        ? _simRoute!.path.goPoints
        : _simRoute!.path.backPoints;
    final stations = _simDirection == Direction.go
        ? _simRoute!.stations.go
        : _simRoute!.stations.back;
    if (points.isEmpty || stationIndex < 0 || stationIndex >= stations.length)
      return;

    if (stationIndex == 0) {
      _currentPathIndex = 0;
      _segmentProgress = 0.0;
      _moveLocationByDistance(0, points, locNotifier);
      return;
    }

    final prevStation = stations[stationIndex - 1];
    final nearest = _findNearestPointOnPath(
      LatLng(prevStation.lat, prevStation.lon),
      points,
    );
    _currentPathIndex = nearest['index'];
    _segmentProgress = nearest['t'];

    _moveLocationByDistance(
      Static.settings.nextStationDepartureDistance + 5.0,
      points,
      locNotifier,
    );
  }

  void jumpToArrivalTrigger(
    int stationIndex,
    LocationChangeNotifier locNotifier,
  ) {
    if (_simRoute == null) return;
    final points = _simDirection == Direction.go
        ? _simRoute!.path.goPoints
        : _simRoute!.path.backPoints;
    final stations = _simDirection == Direction.go
        ? _simRoute!.stations.go
        : _simRoute!.stations.back;
    if (points.isEmpty || stationIndex < 0 || stationIndex >= stations.length)
      return;

    final currentStation = stations[stationIndex];
    final nearest = _findNearestPointOnPath(
      LatLng(currentStation.lat, currentStation.lon),
      points,
    );
    _currentPathIndex = nearest['index'];
    _segmentProgress = nearest['t'];

    double triggerDist = Static.settings.arrivalDistance - 10.0;
    if (triggerDist < 0) triggerDist = 0;

    _moveLocationByDistance(-triggerDist, points, locNotifier);
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

    final targetStation = stations[stationIndex];
    final nearest = _findNearestPointOnPath(
      LatLng(targetStation.lat, targetStation.lon),
      points,
    );
    _currentPathIndex = nearest['index'];
    _segmentProgress = nearest['t'];

    final pStart = points[_currentPathIndex];
    final pEnd = points[(_currentPathIndex + 1).clamp(0, points.length - 1)];
    final bearing = _distanceUtil.bearing(pStart, pEnd);

    locNotifier.updateManualLocation(
      LatLng(
        pStart.latitude + (pEnd.latitude - pStart.latitude) * _segmentProgress,
        pStart.longitude +
            (pEnd.longitude - pStart.longitude) * _segmentProgress,
      ),
      _simSpeedKmh,
      heading: (bearing + 360) % 360,
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
    _simTimer = null;
    _isSimulating = false;
  }

  void _startSimLoop(LocationChangeNotifier locNotifier) {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(Duration(milliseconds: _updateIntervalMs), (
      timer,
    ) {
      if (locNotifier.gpsMode != GpsMode.manual ||
          _simRoute == null ||
          !_isSimulating) {
        _stopSim();
        notifyListeners();
        return;
      }
      final points = _simDirection == Direction.go
          ? _simRoute!.path.goPoints
          : _simRoute!.path.backPoints;
      if (points.length < 2) return;

      double step = (_simSpeedKmh / 3.6) * (_updateIntervalMs / 1000.0);
      _moveLocationByDistance(step, points, locNotifier);
    });
  }

  @override
  void dispose() {
    _stopSim();
    super.dispose();
  }
}
