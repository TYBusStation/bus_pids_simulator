import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_station.dart';
import '../data/status.dart';
import '../utils/route_engine.dart';
import '../utils/static.dart';

class RouteAnalysisProvider extends ChangeNotifier {
  RouteAnalysisResult? _currentAnalysis;
  int? _lastSpokenStationOrder;
  int? _lastArrivedStationOrder;
  DutyStatus? _lastDutyStatus;
  int _activeSequenceId = 0;

  RouteAnalysisResult? get currentAnalysis => _currentAnalysis;

  void update(LatLng? location, Status status) {
    if (location == null || status.dutyStatus != DutyStatus.onDuty) {
      if (_currentAnalysis != null || _lastDutyStatus == DutyStatus.onDuty) {
        _currentAnalysis = null;
        _lastSpokenStationOrder = null;
        _lastArrivedStationOrder = null;
        _lastDutyStatus = status.dutyStatus;
        Static.TTS.stop();
        Static.audioManager.stop();
        notifyListeners();
      }
      return;
    }
    final points = status.direction == Direction.go
        ? status.route.path.goPoints
        : status.route.path.backPoints;
    final stations = status.direction == Direction.go
        ? status.route.stations.go
        : status.route.stations.back;
    if (points.isEmpty || stations.isEmpty) return;
    final result = RouteEngine.analyze(
      currentPos: location,
      routePoints: points,
      stations: stations,
    );
    _currentAnalysis = result;
    _handleTTS(result, status.dutyStatus, stations);
    notifyListeners();
  }

  Future<void> _executeSequence(List<Map<String, dynamic>> sequence) async {
    _activeSequenceId++;
    final int thisId = _activeSequenceId;
    await Static.TTS.stop();
    await Static.audioManager.stop();
    await Future.delayed(const Duration(milliseconds: 50));
    for (var part in sequence) {
      if (thisId != _activeSequenceId) return;
      String text = part['text'];
      double localSpeed = part['speed'] ?? 1.0;

      if (Static.audioManager.hasAudio(text)) {
        await Static.audioManager.playAndWait(text, localSpeed: localSpeed);
      } else {
        await Static.TTS.speak(
          text,
          pitch: part['pitch'] ?? 1.0,
          rate: localSpeed * Static.globalSpeed,
          volume: Static.globalVolume,
        );
      }
    }
  }

  void _handleTTS(RouteAnalysisResult result,
      DutyStatus currentDuty,
      List<BusStation> stations,) {
    if (result.nextStation == null) return;
    final bool isTerminal = result.nextStation!.order == stations.last.order;
    final double distNext = result.distToNextStation ?? double.infinity;
    final double distPrev = result.distToPrevStation ?? 0;
    if (!result.isOffRoute && distNext < 100) {
      if (_lastArrivedStationOrder != result.nextStation!.order) {
        _lastArrivedStationOrder = result.nextStation!.order;
        _executeSequence([
          if (isTerminal) {'text': "終點站", 'pitch': 1.1, 'speed': 0.9},
          {'text': result.nextStation!.name},
          {'text': "到了", 'pitch': 1.1, 'speed': 0.9},
        ]);
      }
      return;
    }
    bool isStartOnDuty =
        _lastDutyStatus != DutyStatus.onDuty &&
            currentDuty == DutyStatus.onDuty;
    bool distanceCondition =
        !result.isOffRoute && (distPrev > 50 || distNext < 250);
    if ((isStartOnDuty || distanceCondition) &&
        _lastSpokenStationOrder != result.nextStation!.order) {
      _lastSpokenStationOrder = result.nextStation!.order;
      _executeSequence([
        {'text': "下一站"},
        if (isTerminal) {'text': "終點站", 'pitch': 1.1, 'speed': 0.9},
        {'text': result.nextStation!.name},
      ]);
    }
    _lastDutyStatus = currentDuty;
  }
}
