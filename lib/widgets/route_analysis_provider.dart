import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_station.dart';
import '../data/status.dart';
import '../utils/route_engine.dart';
import '../utils/static.dart';

class RouteAnalysisProvider extends ChangeNotifier {
  RouteAnalysisResult? _currentAnalysis;
  double _currentSpeed = 0;
  int? _lastSpokenStationOrder;
  int? _lastArrivedStationOrder;
  DutyStatus? _lastDutyStatus;
  int _activeSequenceId = 0;

  RouteAnalysisResult? get currentAnalysis => _currentAnalysis;

  double get currentSpeed => _currentSpeed;

  void update(LatLng? location, double speed, Status status) {
    _currentSpeed = speed;
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
    await Future.delayed(const Duration(milliseconds: 300));
    for (var part in sequence) {
      if (thisId != _activeSequenceId) return;
      String text = part['text'].trim();
      if (text.isEmpty) continue;
      double speed = part['speed'] ?? 1.0;
      if (Static.audioManager.hasAudio(text)) {
        await Static.audioManager.playAndWait(text, localSpeed: speed);
      } else {
        await Static.TTS.speak(
          text,
          pitch: part['pitch'] ?? 1.0,
          rate: speed * Static.globalSpeed,
          volume: Static.globalVolume,
        );
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  List<Map<String, dynamic>> _buildSequence(
    List<String> template,
    String name,
    bool isTerminal,
  ) {
    final List<Map<String, dynamic>> sequence = [];
    for (var item in template) {
      String processed = item
          .replaceAll('{name}', name)
          .replaceAll('{terminal}', isTerminal ? "終點站" : "");
      sequence.add({
        'text': processed,
        'pitch': (processed == "到了" || processed == "終點站") ? 1.1 : 1.0,
        'speed': (processed == "到了" || processed == "終點站") ? 0.9 : 1.0,
      });
    }
    return sequence;
  }

  void _handleTTS(
    RouteAnalysisResult result,
    DutyStatus duty,
    List<BusStation> stations,
  ) {
    if (result.nextStation == null) return;
    final bool isTerminal = result.nextStation!.order == stations.last.order;
    final double distNext = result.distToNextStation ?? double.infinity;
    final double distPrev = result.distToPrevStation ?? 0;

    if (!result.isOffRoute && distNext < Static.arrivalDistance) {
      if (_lastArrivedStationOrder != result.nextStation!.order) {
        _lastArrivedStationOrder = result.nextStation!.order;
        _executeSequence(
          _buildSequence(
            Static.arrivalTemplate,
            result.nextStation!.name,
            isTerminal,
          ),
        );
      }
      return;
    }

    bool isStart =
        _lastDutyStatus != DutyStatus.onDuty && duty == DutyStatus.onDuty;

    bool distCond =
        !result.isOffRoute &&
        (distPrev > Static.nextStationDepartureDistance ||
            distNext < Static.nextStationDistance);

    if ((isStart || distCond) &&
        _lastSpokenStationOrder != result.nextStation!.order) {
      _lastSpokenStationOrder = result.nextStation!.order;
      _executeSequence(
        _buildSequence(
          Static.nextStationTemplate,
          result.nextStation!.name,
          isTerminal,
        ),
      );
    }
    _lastDutyStatus = duty;
  }
}
