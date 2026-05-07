import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_station.dart';
import '../data/status.dart';
import '../utils/route_engine.dart';
import '../utils/static.dart';

enum LedBroadcastType { slogan, next, arrival }

class LedEvent {
  final LedBroadcastType type;
  final String name;
  final String nameEn;
  final bool isTerminal;
  final DateTime timestamp;

  LedEvent({
    required this.type,
    required this.name,
    required this.nameEn,
    this.isTerminal = false,
  }) : timestamp = DateTime.now();
}

class RouteAnalysisProvider extends ChangeNotifier {
  RouteAnalysisResult? _currentAnalysis;
  int? _lastSpokenStationOrder;
  int? _lastArrivedStationOrder;
  DutyStatus? _lastDutyStatus;
  int _activeSequenceId = 0;
  bool _isOffDutyAlert = false;
  LedEvent _currentLedEvent = LedEvent(
    type: LedBroadcastType.slogan,
    name: "",
    nameEn: "",
  );

  RouteAnalysisResult? get currentAnalysis => _currentAnalysis;

  bool get isOffDutyAlert => _isOffDutyAlert;

  LedEvent get currentLedEvent => _currentLedEvent;

  void update(LatLng? location, double speed, Status status) {
    if (status.dutyStatus == DutyStatus.offDuty && speed >= 20) {
      if (!_isOffDutyAlert) {
        _isOffDutyAlert = true;
        _startOffDutyLoop();
        notifyListeners();
      }
    } else if (_isOffDutyAlert) {
      _isOffDutyAlert = false;
      Static.audioManager.stop();
      notifyListeners();
    }

    if (status.dutyStatus != DutyStatus.onDuty) {
      if (_currentAnalysis != null || _lastDutyStatus == DutyStatus.onDuty) {
        _resetAll();
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

    RouteAnalysisResult? result;
    if (location != null && points.isNotEmpty && stations.isNotEmpty) {
      result = RouteEngine.analyze(
        currentPos: location,
        routePoints: points,
        stations: stations,
      );
    }
    _currentAnalysis = result;
    _handleLogic(result, status.dutyStatus, stations);
    notifyListeners();
  }

  void _resetAll() {
    _currentAnalysis = null;
    _lastSpokenStationOrder = null;
    _lastArrivedStationOrder = null;
    _lastDutyStatus = null;
    _currentLedEvent = LedEvent(
      type: LedBroadcastType.slogan,
      name: "",
      nameEn: "",
    );
    Static.TTS.stop();
  }

  Future<void> _startOffDutyLoop() async {
    await Static.audioManager.startAssetLoop("notice.mp3");
  }

  Future<void> _executeVoice(
    List<Map<String, dynamic>> sequence,
    String name,
    String nameEn,
  ) async {
    _activeSequenceId++;
    final int thisId = _activeSequenceId;
    await Static.TTS.stop();
    await Static.audioManager.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    for (var part in sequence) {
      if (thisId != _activeSequenceId || _isOffDutyAlert) return;
      double speed = part['speed'] ?? 1.0;
      if (part['isStationPart']) {
        if (Static.audioManager.hasAudio(name)) {
          await Static.audioManager.playAndWait(name, localSpeed: speed);
        } else {
          await Static.TTS.speak(name, rate: speed * Static.globalSpeed);
          if (nameEn.isNotEmpty) {
            await Future.delayed(const Duration(milliseconds: 100));
            await Static.TTS.speak(
              nameEn,
              rate: speed * Static.globalSpeed - 0.1,
              locale: "en-US",
            );
          }
        }
      } else {
        String text = part['text'].trim();
        if (text.isEmpty) continue;
        if (Static.audioManager.hasAudio(text)) {
          await Static.audioManager.playAndWait(text, localSpeed: speed);
        } else {
          await Static.TTS.speak(text, rate: speed * Static.globalSpeed);
        }
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  void _handleLogic(
    RouteAnalysisResult? result,
    DutyStatus duty,
    List<BusStation> stations,
  ) {
    if (_isOffDutyAlert || result == null || result.nextStation == null) return;

    final bool isTerminal = result.nextStation!.order == stations.last.order;
    final double distNext = result.distToNextStation ?? 10000;
    final double distPrev = result.distToPrevStation ?? 0;

    if (!result.isOffRoute && distNext < Static.arrivalDistance) {
      if (_lastArrivedStationOrder != result.nextStation!.order) {
        _lastArrivedStationOrder = result.nextStation!.order;
        _currentLedEvent = LedEvent(
          type: LedBroadcastType.arrival,
          name: result.nextStation!.name,
          nameEn: result.nextStation!.nameEn,
        );
        _executeVoice(
          _buildSeq(
            Static.arrivalTemplate,
            result.nextStation!.name,
            isTerminal,
          ),
          result.nextStation!.name,
          result.nextStation!.nameEn,
        );
        notifyListeners();
      }
      return;
    }

    bool distCond =
        !result.isOffRoute &&
        (distPrev > Static.nextStationDepartureDistance ||
            distNext < Static.nextStationDistance);
    if ((_lastDutyStatus != DutyStatus.onDuty || distCond) &&
        _lastSpokenStationOrder != result.nextStation!.order) {
      _lastSpokenStationOrder = result.nextStation!.order;
      _currentLedEvent = LedEvent(
        type: LedBroadcastType.next,
        name: result.nextStation!.name,
        nameEn: result.nextStation!.nameEn,
        isTerminal: isTerminal,
      );
      _executeVoice(
        _buildSeq(
          Static.nextStationTemplate,
          result.nextStation!.name,
          isTerminal,
        ),
        result.nextStation!.name,
        result.nextStation!.nameEn,
      );
      notifyListeners();
    }
    _lastDutyStatus = duty;
  }

  List<Map<String, dynamic>> _buildSeq(List<String> tmp, String n, bool t) {
    return tmp
        .map(
          (i) => {
            'text': i
                .replaceAll('{name}', n)
                .replaceAll('{terminal}', t ? "終點站" : ""),
            'isStationPart': i.contains('{name}'),
            'speed': (i == "到了" || i == "終點站") ? 0.9 : 1.0,
          },
        )
        .toList();
  }
}
