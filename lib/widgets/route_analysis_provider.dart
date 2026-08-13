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
  final String name, nameEn;
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
  BusStation? _displayStation;
  int? _lastSpokenStationOrder,
      _lastArrivedStationOrder,
      _lastSpeedWarningStationOrder;
  DutyStatus? _lastDutyStatus;
  int _activeSequenceId = 0;
  LatLng? _lastProcessedLocation;
  int _lastUpdateTimestamp = 0;
  Direction? _lastDirection;
  bool _isOffDutyAlert = false;
  LedEvent _currentLedEvent = LedEvent(
    type: LedBroadcastType.slogan,
    name: "",
    nameEn: "",
  );
  final List<MapEntry<DateTime, double>> _speedHistory = [];
  final _eventController = StreamController<String>.broadcast();

  Stream<String> get eventStream => _eventController.stream;

  RouteAnalysisResult? get currentAnalysis => _currentAnalysis;

  BusStation? get displayStation => _displayStation;

  bool get isOffDutyAlert => _isOffDutyAlert;

  LedEvent get currentLedEvent => _currentLedEvent;

  void resetAnalysis() {
    _activeSequenceId++;
    Static.TTS.stop();
    Static.audioManager.stop();
    _currentAnalysis = null;
    _displayStation = null;
    _lastSpokenStationOrder = null;
    _lastArrivedStationOrder = null;
    _lastSpeedWarningStationOrder = null;
    _lastDutyStatus = null;
    _speedHistory.clear();
    _currentLedEvent = LedEvent(
      type: LedBroadcastType.slogan,
      name: "",
      nameEn: "",
    );
    notifyListeners();
  }

  void update(
    LatLng? location,
    double speed,
    Status status, {
    double accuracy = 0,
    double? heading,
  }) {
    if (accuracy > 50) return;
    final now = DateTime.now();
    final int nowMs = now.millisecondsSinceEpoch;

    if (location != null && _lastProcessedLocation != null) {
      final double dist = const Distance().as(
        LengthUnit.Meter,
        _lastProcessedLocation!,
        location,
      );
      if (dist < 1.0 &&
          status.dutyStatus == _lastDutyStatus &&
          status.direction == _lastDirection &&
          (nowMs - _lastUpdateTimestamp) < 1000) {
        return;
      }
    }

    _lastUpdateTimestamp = nowMs;
    _lastProcessedLocation = location;
    _lastDirection = status.direction;

    _speedHistory.add(MapEntry(now, speed));
    if (_speedHistory.length > 60) _speedHistory.removeAt(0);
    _speedHistory.removeWhere((e) => now.difference(e.key).inMinutes > 2);

    if (status.dutyStatus == DutyStatus.offDuty) {
      if (speed >= 10 && !_isOffDutyAlert) {
        _isOffDutyAlert = true;
        Static.TTS.speak(" ");
        _startOffDutyLoop();
        notifyListeners();
      } else if (speed < 10 && _isOffDutyAlert) {
        _isOffDutyAlert = false;
        Static.audioManager.stop();
        notifyListeners();
      }
      if (_lastDutyStatus == DutyStatus.onDuty) resetAnalysis();
      _currentAnalysis = null;
      _lastDutyStatus = DutyStatus.offDuty;
      return;
    }

    if (status.dutyStatus == DutyStatus.onDuty && _isOffDutyAlert) {
      _isOffDutyAlert = false;
      Static.audioManager.stop();
    }

    final stations = status.direction == Direction.go
        ? status.route.stations.go
        : status.route.stations.back;

    if (_lastDutyStatus != DutyStatus.onDuty) {
      _lastDutyStatus = DutyStatus.onDuty;
      _lastSpokenStationOrder = null;
      _lastArrivedStationOrder = null;
      Static.audioManager.preloadRouteStations(
        stations.map((s) => s.name).toList(),
      );
    }

    final points = status.direction == Direction.go
        ? status.route.path.goPoints
        : status.route.path.backPoints;

    if (location == null || stations.isEmpty || points.isEmpty) {
      _currentAnalysis = null;
    } else {
      _currentAnalysis = RouteEngine.analyze(
        currentPos: location,
        routePoints: points,
        stations: stations,
        heading: heading,
      );
    }

    _handleLogic(_currentAnalysis, status, stations);
    if (_currentAnalysis != null) {
      _checkSpeeding(_currentAnalysis!, speed);
    }
    notifyListeners();
  }

  void _handleLogic(
    RouteAnalysisResult? result,
    Status status,
    List<BusStation> stations,
  ) {
    if (_isOffDutyAlert || _lastDutyStatus != DutyStatus.onDuty) return;
    BusStation? next;
    bool isOffRoute = result?.isOffRoute ?? true;
    if (result == null || isOffRoute) {
      next = stations.isNotEmpty ? stations.first : BusStation(order: 0);
    } else {
      next = result.nextStation;
    }
    if (next == null) return;

    final int terminalOrder = stations.isNotEmpty ? stations.last.order : -1;
    bool shouldSpeakNext = false;
    if (_lastSpokenStationOrder == null) {
      shouldSpeakNext = true;
    } else if (result != null && !isOffRoute) {
      final double distNext = result.distToNextStation ?? 1000000;
      final double distPrev = result.distToPrevStation ?? 0;
      if (distPrev > 5 &&
          (distPrev > Static.settings.nextStationDepartureDistance ||
              (Static.settings.nextStationDistance >= 0 &&
                  distNext < Static.settings.nextStationDistance))) {
        shouldSpeakNext = true;
      }
    }

    if (shouldSpeakNext) {
      _triggerNextStationBroadcast(next, terminalOrder, status);
    }

    if (result != null && !isOffRoute) {
      final double distNext = result.distToNextStation ?? 1000000;
      if (Static.settings.arrivalDistance >= 0 &&
          distNext < Static.settings.arrivalDistance &&
          _lastArrivedStationOrder != next.order) {
        _lastArrivedStationOrder = next.order;
        _displayStation = next;
        _currentLedEvent = LedEvent(
          type: LedBroadcastType.arrival,
          name: next.name,
          nameEn: next.nameEn,
          isTerminal: next.order == terminalOrder,
        );
        if (Static.settings.enableArrivalBroadcast) {
          final template =
              (next.useGlobalArrival || next.arrivalTemplate == null)
              ? Static.settings.arrivalTemplate
              : next.arrivalTemplate!;
          if (template.isNotEmpty) {
            final vars = getFormattedVariables(_currentLedEvent, status);
            _executeVoice(
              _buildSeq(
                template,
                next,
                next.order == terminalOrder,
                status,
                vars,
              ),
            );
          }
        }
      }
    }
  }

  double getEffectiveSpeedMs() {
    if (_speedHistory.isEmpty) return 20.0 / 3.6;
    final recent = _speedHistory.reversed.take(10).map((e) => e.value).toList();
    double avgKmh = recent.reduce((a, b) => a + b) / recent.length;
    return (avgKmh < 5.0) ? 20.0 / 3.6 : avgKmh / 3.6;
  }

  String _performReplacement(String template, Map<String, String> vars) {
    String res = template;
    final keys = vars.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (var k in keys) {
      res = res.replaceAll('{$k}', vars[k] ?? "");
    }
    return res;
  }

  Map<String, String> getFormattedVariables(LedEvent event, Status status) {
    final now = DateTime.now();
    final double avgSpeedMs = getEffectiveSpeedMs();
    String dest = status.direction == Direction.go
        ? status.route.destination
        : status.route.departure;
    String dep = status.direction == Direction.go
        ? status.route.departure
        : status.route.destination;
    final stations = status.direction == Direction.go
        ? status.route.stations.go
        : status.route.stations.back;

    BusStation? targetStation = _displayStation;
    if (targetStation == null && stations.isNotEmpty)
      targetStation = stations.first;

    int idx = (targetStation != null)
        ? stations.indexWhere((s) => s.order == targetStation!.order)
        : -1;

    Map<String, String> map = {
      'name': event.name.isEmpty ? (targetStation?.name ?? "") : event.name,
      'nameEn': event.nameEn.isEmpty
          ? (targetStation?.nameEn ?? "")
          : event.nameEn,
      'terminal': event.isTerminal ? "終點站" : "",
      'route_name': status.route.name,
      'route_desc': status.route.description,
      'route_dest': dest,
      'route_dep': dep,
      'hh': now.hour.toString().padLeft(2, '0'),
      'mm': now.minute.toString().padLeft(2, '0'),
      'ss': now.second.toString().padLeft(2, '0'),
    };

    if (idx != -1 && _currentAnalysis != null) {
      double distToNext = _currentAnalysis!.distToNextStation ?? 0;
      double secondsToNext = distToNext / avgSpeedMs;
      DateTime nextEst = now.add(Duration(seconds: secondsToNext.round()));
      map['currMin'] = (secondsToNext / 60).ceil().toString();
      map['currTimeHH'] = nextEst.hour.toString().padLeft(2, '0');
      map['currTimeMM'] = nextEst.minute.toString().padLeft(2, '0');

      double cumulativeSeconds = secondsToNext;
      for (int i = 1; i <= 15; i++) {
        if (idx + i < stations.length) {
          final targetIdx = idx + i;
          double posCurrent =
              _currentAnalysis!.stationPositions[stations[targetIdx - 1]
                  .order] ??
              0;
          double posNext =
              _currentAnalysis!.stationPositions[stations[targetIdx].order] ??
              0;
          double segmentDist = (posNext - posCurrent).abs() * 1000;
          cumulativeSeconds += (segmentDist / avgSpeedMs) + 50;
          DateTime est = now.add(Duration(seconds: cumulativeSeconds.round()));
          map['NextName$i'] = stations[targetIdx].name;
          map['NextMin$i'] = (cumulativeSeconds / 60).ceil().toString();
          map['NextTimeHH$i'] = est.hour.toString().padLeft(2, '0');
          map['NextTimeMM$i'] = est.minute.toString().padLeft(2, '0');
        }
      }
    }

    Static.settings.customVariables.forEach((key, template) {
      map[key] = _performReplacement(template, map);
    });
    return map;
  }

  String formatTemplate(String template, LedEvent event, Status status) {
    Map<String, String> vars = getFormattedVariables(event, status);
    String res = _performReplacement(template, vars);
    res = res.replaceAll(RegExp(r'\{(A|B|AE|BE)\((.*?)\)\}'), "");
    return res;
  }

  void _checkSpeeding(RouteAnalysisResult result, double speed) {
    final next = result.nextStation;
    if (next == null) return;
    if ((result.distToNextStation ?? 10000) < Static.settings.arrivalDistance &&
        speed > 60) {
      if (_lastSpeedWarningStationOrder != next.order) {
        _lastSpeedWarningStationOrder = next.order;
        _eventController.add("SPEED_WARNING");
      }
    }
  }

  Future<void> _startOffDutyLoop() async {
    final int thisId = _activeSequenceId;
    while (_isOffDutyAlert && thisId == _activeSequenceId) {
      try {
        await Static.audioManager.playAssetAndWait("notice.mp3");
      } catch (_) {}
      if (!_isOffDutyAlert) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _executeVoice(List<Map<String, dynamic>> sequence) async {
    _activeSequenceId++;
    final int thisId = _activeSequenceId;
    await Static.TTS.stop();
    await Static.audioManager.stop();
    await Future.delayed(const Duration(milliseconds: 50));
    for (var part in sequence) {
      if (thisId != _activeSequenceId ||
          _isOffDutyAlert ||
          _lastDutyStatus != DutyStatus.onDuty)
        return;
      String audioKey = (part['audioKey'] as String).replaceAll("/", ""),
          text = part['text'] as String;
      double speed = (part['speed'] as double) * Static.settings.globalSpeed;
      if (audioKey.isNotEmpty && Static.audioManager.hasAudio(audioKey))
        await Static.audioManager.playAndWait(
          audioKey,
          localSpeed: part['speed'] as double,
        );
      else if (text.isNotEmpty)
        await Static.TTS.speak(
          text,
          rate: speed.clamp(0.5, 2.0),
          volume: Static.settings.globalVolume,
          locale: part['locale'] as String,
        );
      await Future.delayed(
        Duration(milliseconds: Static.settings.voiceSegmentDelay.round()),
      );
    }
  }

  void _triggerNextStationBroadcast(
    BusStation station,
    int terminalOrder,
    Status status,
  ) {
    if (_lastDutyStatus != DutyStatus.onDuty ||
        _lastSpokenStationOrder == station.order)
      return;
    final bool isTerminal = station.order == terminalOrder;
    _lastSpokenStationOrder = station.order;
    _displayStation = station;
    _currentLedEvent = LedEvent(
      type: LedBroadcastType.next,
      name: station.name,
      nameEn: station.nameEn,
      isTerminal: isTerminal,
    );
    final vars = getFormattedVariables(_currentLedEvent, status);
    notifyListeners();
    final template = (station.useGlobalNext || station.nextTemplate == null)
        ? Static.settings.nextStationTemplate
        : station.nextTemplate!;
    if (template.isNotEmpty)
      _executeVoice(_buildSeq(template, station, isTerminal, status, vars));
  }

  List<Map<String, dynamic>> _expandVoiceText(
    String text,
    Map<String, String> vars,
    String locale,
  ) {
    String processed = _performReplacement(text, vars);
    if (processed.trim().isEmpty) return [];
    String audioKey = processed;
    String ttsText = processed.replaceAll(RegExp(r'_(國|英|閩|客)$'), "");
    return [
      {'text': ttsText, 'audioKey': audioKey, 'locale': locale},
    ];
  }

  List<Map<String, dynamic>> _buildSeq(
    List<String> template,
    BusStation station,
    bool isTerminal,
    Status status,
    Map<String, String> vars,
  ) {
    String currentName = vars['name'] ?? station.name;
    String currentNameEn = vars['nameEn'] ?? station.nameEn;
    bool hasFullAudio = Static.audioManager.hasAudio(currentName);
    List<String> baseExpanded = [];
    for (var item in template) {
      if (item == "{name}") {
        if (hasFullAudio)
          baseExpanded.add("{name_full}");
        else
          baseExpanded.addAll(Static.settings.stationVoiceSequence);
      } else
        baseExpanded.add(item);
    }
    List<Map<String, dynamic>> finalSequence = [];
    for (var item in baseExpanded) {
      if (item == "{name_full}") {
        finalSequence.add({
          'text': currentName,
          'audioKey': currentName,
          'locale': 'zh-TW',
        });
      } else if (item == "{name_zh}") {
        finalSequence.add({
          'text': currentName,
          'audioKey': "${currentName}_國",
          'locale': 'zh-TW',
        });
      } else if (item == "{name_en}") {
        String ak = Static.audioManager.hasAudio(currentNameEn)
            ? currentNameEn
            : "${currentName}_英";
        finalSequence.add({
          'text': currentNameEn,
          'audioKey': ak,
          'locale': 'en-US',
        });
      } else if (item == "{name_ho}") {
        finalSequence.add({
          'text': "",
          'audioKey': "${currentName}_閩",
          'locale': 'zh-TW',
        });
      } else if (item == "{name_hk}") {
        finalSequence.add({
          'text': "",
          'audioKey': "${currentName}_客",
          'locale': 'zh-TW',
        });
      } else {
        String locale = item.contains(RegExp(r'[a-zA-Z]')) ? 'en-US' : 'zh-TW';
        if (item.contains("_英")) locale = 'en-US';
        if (item.contains("_國") || item.contains("_閩") || item.contains("_客"))
          locale = 'zh-TW';
        finalSequence.addAll(_expandVoiceText(item, vars, locale));
      }
    }
    return finalSequence
        .map((m) {
          String tx = m['text'] as String;
          return {...m, 'speed': (tx == "到了" || tx == "終點站") ? 0.9 : 1.0};
        })
        .where((m) {
          final String ak = m['audioKey'] as String;
          return ak.isNotEmpty || (m['text'] as String).trim().isNotEmpty;
        })
        .toList();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}
