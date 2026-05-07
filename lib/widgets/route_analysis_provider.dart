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

    final stations = status.direction == Direction.go
        ? status.route.stations.go
        : status.route.stations.back;
    bool justTurnedOn =
        _lastDutyStatus != DutyStatus.onDuty &&
        status.dutyStatus == DutyStatus.onDuty;

    if (justTurnedOn) {
      _lastDutyStatus = DutyStatus.onDuty;
      _lastSpokenStationOrder = null;
      _lastArrivedStationOrder = null;
      _triggerNextStationBroadcast(
        stations.isNotEmpty ? stations.first : null,
        stations.isNotEmpty ? stations.last.order : null,
      );
    }

    if (status.dutyStatus != DutyStatus.onDuty) {
      if (_currentAnalysis != null) {
        _resetLogicOnly();
        notifyListeners();
      }
      _lastDutyStatus = status.dutyStatus;
      return;
    }

    final points = status.direction == Direction.go
        ? status.route.path.goPoints
        : status.route.path.backPoints;
    RouteAnalysisResult? result;
    if (location != null && points.isNotEmpty && stations.isNotEmpty) {
      result = RouteEngine.analyze(
        currentPos: location,
        routePoints: points,
        stations: stations,
      );
    }

    _currentAnalysis = result;
    _lastDutyStatus = status.dutyStatus;

    if (result != null) {
      _handleLogic(result, status.dutyStatus, stations);
    }

    notifyListeners();
  }

  void _resetLogicOnly() {
    _currentAnalysis = null;
    _lastSpokenStationOrder = null;
    _lastArrivedStationOrder = null;
    _currentLedEvent = LedEvent(
      type: LedBroadcastType.slogan,
      name: "",
      nameEn: "",
    );
    Static.TTS.stop();
  }

  Future<void> _startOffDutyLoop() async {
    while (_isOffDutyAlert) {
      await Static.audioManager.playAssetAndWait("notice.mp3");
      if (!_isOffDutyAlert) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }
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
      double finalSpeed = speed * Static.globalSpeed;
      double finalVol = Static.globalVolume;

      if (part['isStationPart']) {
        if (name.isEmpty) continue;
        if (Static.audioManager.hasAudio(name)) {
          await Static.audioManager.playAndWait(name, localSpeed: speed);
        } else {
          await Static.TTS.speak(
            name,
            rate: finalSpeed.clamp(0.5, 2.0),
            volume: finalVol,
          );
          if (nameEn.isNotEmpty) {
            await Future.delayed(const Duration(milliseconds: 100));
            await Static.TTS.speak(
              nameEn,
              rate: (finalSpeed - 0.1).clamp(0.5, 2.0),
              volume: finalVol,
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
          await Static.TTS.speak(
            text,
            rate: finalSpeed.clamp(0.5, 2.0),
            volume: finalVol,
          );
        }
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  void _triggerNextStationBroadcast(BusStation? station, int? terminalOrder) {
    final int order = station?.order ?? -1;
    if (_lastSpokenStationOrder == order) return;
    final bool isTerminal = (station != null && terminalOrder != null)
        ? station.order == terminalOrder
        : false;
    _lastSpokenStationOrder = order;
    final String name = station?.name ?? "";
    final String nameEn = station?.nameEn ?? "";

    _currentLedEvent = LedEvent(
      type: LedBroadcastType.next,
      name: name,
      nameEn: nameEn,
      isTerminal: isTerminal,
    );
    _executeVoice(
      _buildSeq(Static.nextStationTemplate, name, isTerminal),
      name,
      nameEn,
    );
  }

  void _handleLogic(
    RouteAnalysisResult result,
    DutyStatus duty,
    List<BusStation> stations,
  ) {
    if (_isOffDutyAlert) return;
    final BusStation? nextStation = result.nextStation;
    final int? terminalOrder = stations.isNotEmpty ? stations.last.order : null;

    if (nextStation != null) {
      final bool isTerminal = nextStation.order == stations.last.order;
      final double distNext = result.distToNextStation ?? 10000;
      if (!result.isOffRoute && distNext < Static.arrivalDistance) {
        if (_lastArrivedStationOrder != nextStation.order) {
          _lastArrivedStationOrder = nextStation.order;
          _currentLedEvent = LedEvent(
            type: LedBroadcastType.arrival,
            name: nextStation.name,
            nameEn: nextStation.nameEn,
          );
          _executeVoice(
            _buildSeq(Static.arrivalTemplate, nextStation.name, isTerminal),
            nextStation.name,
            nextStation.nameEn,
          );
        }
        return;
      }
    }

    final double distNext = result.distToNextStation ?? 10000;
    final double distPrev = result.distToPrevStation ?? 0;
    bool distCond =
        !result.isOffRoute &&
        (distPrev > Static.nextStationDepartureDistance ||
            distNext < Static.nextStationDistance);
    if (distCond || (nextStation == null && _lastSpokenStationOrder != -1)) {
      _triggerNextStationBroadcast(nextStation, terminalOrder);
    }
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
