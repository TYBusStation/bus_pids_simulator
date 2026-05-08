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

  Future<void> _executeVoice(List<Map<String, dynamic>> sequence) async {
    _activeSequenceId++;
    final int thisId = _activeSequenceId;
    await Static.TTS.stop();
    await Static.audioManager.stop();
    await Future.delayed(const Duration(milliseconds: 100));

    for (var part in sequence) {
      if (thisId != _activeSequenceId || _isOffDutyAlert) return;

      String audioKey = part['audioKey'];
      String text = part['text'];
      String locale = part['locale'];
      double speed = part['speed'] * Static.globalSpeed;

      if (Static.audioManager.hasAudio(audioKey)) {
        await Static.audioManager.playAndWait(
          audioKey,
          localSpeed: part['speed'],
        );
      } else if (text.isNotEmpty) {
        if (audioKey.endsWith("_ho") || audioKey.endsWith("_hk")) continue;

        await Static.TTS.speak(
          text,
          rate: speed.clamp(0.5, 2.0),
          volume: Static.globalVolume,
          locale: locale,
        );
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
      _buildSeq(Static.nextStationTemplate, name, nameEn, isTerminal),
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

      if (Static.arrivalDistance >= 0 &&
          !result.isOffRoute &&
          distNext < Static.arrivalDistance) {
        if (_lastArrivedStationOrder != nextStation.order) {
          _lastArrivedStationOrder = nextStation.order;
          _currentLedEvent = LedEvent(
            type: LedBroadcastType.arrival,
            name: nextStation.name,
            nameEn: nextStation.nameEn,
          );
          _executeVoice(
            _buildSeq(
              Static.arrivalTemplate,
              nextStation.name,
              nextStation.nameEn,
              isTerminal,
            ),
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
            (Static.nextStationDistance >= 0 &&
                distNext < Static.nextStationDistance));

    if (distCond || (nextStation == null && _lastSpokenStationOrder != -1)) {
      _triggerNextStationBroadcast(nextStation, terminalOrder);
    }
  }

  List<Map<String, dynamic>> _buildSeq(
    List<String> template,
    String name,
    String nameEn,
    bool isTerminal,
  ) {
    // 檢查是否有站點名稱的音檔 (假設音檔 Key 即為站名)
    bool hasAudio = Static.audioManager.hasAudio(name);

    List<String> expanded = [];
    for (var item in template) {
      if (item == "{station_voices}") {
        if (hasAudio) {
          expanded.add("{name_zh}");
        } else {
          expanded.addAll(Static.stationVoiceSequence);
        }
      } else {
        expanded.add(item);
      }
    }

    return expanded
        .map((item) {
          String audioKey = "";
          String text = "";
          String locale = "zh-TW";

          if (item.contains('{name_en}')) {
            text = nameEn;
            audioKey = nameEn;
            locale = "en-US";
          } else if (item.contains('{name_zh}')) {
            text = name;
            audioKey = name;
          } else if (item.contains('{name_ho}')) {
            text = name;
            audioKey = "${name}_ho";
          } else if (item.contains('{name_hk}')) {
            text = name;
            audioKey = "${name}_hk";
          } else {
            text = item
                .replaceAll('{terminal}', isTerminal ? "終點站" : "")
                .replaceAll('{name_zh}', name);
            audioKey = text;
          }

          return {
            'text': text,
            'audioKey': audioKey,
            'locale': locale,
            'speed': (text == "到了" || text == "終點站") ? 0.9 : 1.0,
          };
        })
        .where((m) => m['text'].toString().trim().isNotEmpty)
        .toList();
  }
}
