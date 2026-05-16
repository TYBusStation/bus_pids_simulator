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
  int? _lastSpeedWarningStationOrder;
  DutyStatus? _lastDutyStatus;
  int _activeSequenceId = 0;
  bool _isOffDutyAlert = false;
  LedEvent _currentLedEvent = LedEvent(
    type: LedBroadcastType.slogan,
    name: "",
    nameEn: "",
  );

  final _eventController = StreamController<String>.broadcast();

  Stream<String> get eventStream => _eventController.stream;

  RouteAnalysisResult? get currentAnalysis => _currentAnalysis;

  bool get isOffDutyAlert => _isOffDutyAlert;

  LedEvent get currentLedEvent => _currentLedEvent;

  void resetAnalysis() {
    _activeSequenceId++;
    Static.TTS.stop();
    Static.audioManager.stop();
    _currentAnalysis = null;
    _lastSpokenStationOrder = null;
    _lastArrivedStationOrder = null;
    _lastSpeedWarningStationOrder = null;
    _lastDutyStatus = null;
    _currentLedEvent = LedEvent(
      type: LedBroadcastType.slogan,
      name: "",
      nameEn: "",
    );
    notifyListeners();
  }

  void update(LatLng? location, double speed, Status status) {
    if (status.dutyStatus == DutyStatus.offDuty && speed >= 10) {
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
      if (_lastDutyStatus == DutyStatus.onDuty) {
        resetAnalysis();
      }
      _currentAnalysis = null;
      _lastDutyStatus = DutyStatus.offDuty;
      return;
    }

    final stations = status.direction == Direction.go
        ? status.route.stations.go
        : status.route.stations.back;

    if (_lastDutyStatus != DutyStatus.onDuty) {
      _lastDutyStatus = DutyStatus.onDuty;
      _lastSpokenStationOrder = null;
      _lastArrivedStationOrder = null;

      if (stations.isNotEmpty) {
        _triggerNextStationBroadcast(
          stations.first,
          stations.last.order,
          status,
        );
      } else {
        _executeVoice(_buildSeq(Static.nextStationTemplate, "", "", false));
      }
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
    if (result != null) {
      _handleLogic(result, status, stations);
      _checkSpeeding(result, speed);
    }
    notifyListeners();
  }

  void _checkSpeeding(RouteAnalysisResult result, double speed) {
    final nextStation = result.nextStation;
    if (nextStation == null) return;
    final double distNext = result.distToNextStation ?? 10000;
    if (distNext < Static.arrivalDistance && speed > 60) {
      if (_lastSpeedWarningStationOrder != nextStation.order) {
        _lastSpeedWarningStationOrder = nextStation.order;
        _eventController.add("SPEED_WARNING");
      }
    }
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
      if (thisId != _activeSequenceId ||
          _isOffDutyAlert ||
          _lastDutyStatus != DutyStatus.onDuty)
        return;
      String audioKey = part['audioKey'] as String;
      String text = part['text'] as String;
      String locale = part['locale'] as String;
      double speed = (part['speed'] as double) * Static.globalSpeed;
      if (audioKey.isNotEmpty && Static.audioManager.hasAudio(audioKey)) {
        await Static.audioManager.playAndWait(
          audioKey,
          localSpeed: part['speed'] as double,
        );
      } else if (text.isNotEmpty) {
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

  void _triggerNextStationBroadcast(
    BusStation station,
    int terminalOrder,
    Status status,
  ) {
    if (_lastDutyStatus != DutyStatus.onDuty) return;
    if (_lastSpokenStationOrder == station.order) return;
    final bool isTerminal = station.order == terminalOrder;
    _lastSpokenStationOrder = station.order;
    _currentLedEvent = LedEvent(
      type: LedBroadcastType.next,
      name: station.name,
      nameEn: station.nameEn,
      isTerminal: isTerminal,
    );
    notifyListeners();
    _executeVoice(
      _buildSeq(
        Static.nextStationTemplate,
        station.name,
        station.nameEn,
        isTerminal,
      ),
    );
  }

  void _handleLogic(
    RouteAnalysisResult result,
    Status status,
    List<BusStation> stations,
  ) {
    if (_isOffDutyAlert || _lastDutyStatus != DutyStatus.onDuty) return;
    final BusStation? nextStation = result.nextStation;
    final int terminalOrder = stations.isNotEmpty ? stations.last.order : -1;

    if (nextStation != null) {
      final double distNext = result.distToNextStation ?? 10000;
      final double distPrev = result.distToPrevStation ?? 0;

      bool distCond =
          !result.isOffRoute &&
          (distPrev > Static.nextStationDepartureDistance ||
              (Static.nextStationDistance >= 0 &&
                  distNext < Static.nextStationDistance));

      if (distCond || _lastSpokenStationOrder == null) {
        _triggerNextStationBroadcast(nextStation, terminalOrder, status);
      }

      final bool isTerminal = nextStation.order == terminalOrder;
      if (Static.arrivalDistance >= 0 &&
          !result.isOffRoute &&
          distNext < Static.arrivalDistance) {
        if (_lastArrivedStationOrder != nextStation.order) {
          _lastArrivedStationOrder = nextStation.order;
          _currentLedEvent = LedEvent(
            type: LedBroadcastType.arrival,
            name: nextStation.name,
            nameEn: nextStation.nameEn,
            isTerminal: isTerminal,
          );
          notifyListeners();
          if (Static.enableArrivalBroadcast) {
            _executeVoice(
              _buildSeq(
                Static.arrivalTemplate,
                nextStation.name,
                nextStation.nameEn,
                isTerminal,
              ),
            );
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _buildSeq(
    List<String> template,
    String name,
    String nameEn,
    bool isTerminal,
  ) {
    bool hasFullAudio = Static.audioManager.hasAudio(name);
    List<String> expanded = [];
    for (var item in template) {
      if (item == "{name}") {
        if (hasFullAudio)
          expanded.add("{name_full}");
        else
          expanded.addAll(Static.stationVoiceSequence);
      } else {
        expanded.add(item);
      }
    }
    return expanded
        .map<Map<String, dynamic>>((item) {
          String audioKey = "";
          String text = "";
          String locale = "zh-TW";
          if (item == "{name_full}") {
            audioKey = name;
            text = name;
          } else if (item == "{name_zh}") {
            audioKey = "${name}_國";
            text = name;
          } else if (item == "{name_en}") {
            audioKey = "${name}_英";
            text = nameEn;
            locale = "en-US";
          } else if (item == "{name_ho}") {
            audioKey = "${name}_閩";
            text = "";
          } else if (item == "{name_hk}") {
            audioKey = "${name}_客";
            text = "";
          } else {
            text = item
                .replaceAll('{terminal}', isTerminal ? "終點站" : "")
                .replaceAll('{name_zh}', name)
                .replaceAll('{name_ho}', "")
                .replaceAll('{name_hk}', "")
                .replaceAll('{name_en}', nameEn)
                .replaceAll('{name}', name);
            audioKey = text;
          }
          return {
            'text': text,
            'audioKey': audioKey,
            'locale': locale,
            'speed': (text == "到了" || text == "終點站") ? 0.9 : 1.0,
          };
        })
        .where((m) {
          final String ak = m['audioKey'] as String;
          final String txt = m['text'] as String;
          if (ak.endsWith("_閩") || ak.endsWith("_客"))
            return Static.audioManager.hasAudio(ak);
          return ak.trim().isNotEmpty || txt.trim().isNotEmpty;
        })
        .toList();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}
