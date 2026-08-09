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

  void update(LatLng? location,
      double speed,
      Status status, {
        double accuracy = 0,
        double? heading,
      }) {
    if (accuracy > 50) return;
    final now = DateTime.now();
    _speedHistory.add(MapEntry(now, speed));
    _speedHistory.removeWhere((e) =>
    now
        .difference(e.key)
        .inMinutes > 3);

    if (status.dutyStatus == DutyStatus.offDuty && speed >= 10) {
      if (!_isOffDutyAlert) {
        _isOffDutyAlert = true;
        Static.TTS.speak(" ");
        _startOffDutyLoop();
        notifyListeners();
      }
    } else if (_isOffDutyAlert) {
      _isOffDutyAlert = false;
      Static.audioManager.stop();
      notifyListeners();
    }

    if (status.dutyStatus != DutyStatus.onDuty) {
      if (_lastDutyStatus == DutyStatus.onDuty) resetAnalysis();
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

      Static.audioManager.preloadRouteStations(
        stations.map((s) => s.name).toList(),
      );
    }

    final points = status.direction == Direction.go
        ? status.route.path.goPoints
        : status.route.path.backPoints;

    _currentAnalysis =
    (location != null && points.isNotEmpty && stations.isNotEmpty)
        ? RouteEngine.analyze(
      currentPos: location,
      routePoints: points,
      stations: stations,
      heading: heading,
    )
        : null;

    if (_currentAnalysis != null) {
      _handleLogic(_currentAnalysis!, status, stations);
      _checkSpeeding(_currentAnalysis!, speed);
    }
    notifyListeners();
  }

  double getEffectiveSpeedMs() {
    if (_speedHistory.isEmpty) return 20.0 / 3.6;
    List<double> speeds = _speedHistory.map((e) => e.value).toList()
      ..sort();
    int n = speeds.length,
        skip = (n * 0.125).floor(),
        take = n - (2 * skip);
    double avgKmh;
    if (take <= 0) {
      avgKmh = speeds.reduce((a, b) => a + b) / n;
    } else {
      List<double> filtered = speeds.skip(skip).take(take).toList();
      avgKmh = filtered.reduce((a, b) => a + b) / filtered.length;
    }
    if (avgKmh < 5.0) return 20.0 / 3.6;
    return avgKmh / 3.6;
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
    if (targetStation == null && stations.isNotEmpty) {
      targetStation = stations.first;
    }

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
        String pN = "",
            pE = "",
            nN = "",
            nE = "",
            nMin = "0",
            nHH = "0",
            nMM = "0";
        if (idx - i >= 0) {
          pN = stations[idx - i].name;
          pE = stations[idx - i].nameEn;
        }
        if (idx + i < stations.length) {
          final targetIdx = idx + i;
          nN = stations[targetIdx].name;
          nE = stations[targetIdx].nameEn;
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
          nMin = (cumulativeSeconds / 60).ceil().toString();
          nHH = est.hour.toString().padLeft(2, '0');
          nMM = est.minute.toString().padLeft(2, '0');
        }
        map['PrevName$i'] = pN;
        map['PrevNameEn$i'] = pE;
        map['NextName$i'] = nN;
        map['NextNameEn$i'] = nE;
        map['NextMin$i'] = nMin;
        map['NextTimeHH$i'] = nHH;
        map['NextTimeMM$i'] = nMM;
      }
    } else {
      map['currMin'] = "0";
      map['currTimeHH'] = "0";
      map['currTimeMM'] = "0";
      for (int i = 1; i <= 15; i++) {
        map['PrevName$i'] = "";
        map['PrevNameEn$i'] = "";
        map['NextName$i'] = "";
        map['NextNameEn$i'] = "";
        map['NextMin$i'] = "0";
        map['NextTimeHH$i'] = "0";
        map['NextTimeMM$i'] = "0";
      }
    }

    final keys = map.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    Static.settings.customVariables.forEach((key, template) {
      String processed = template;
      for (var k in keys) {
        processed = processed.replaceAll('{$k}', map[k] ?? "");
      }
      map[key] = processed;
    });
    return map;
  }

  String formatTemplate(String template, LedEvent event, Status status) {
    Map<String, String> vars = getFormattedVariables(event, status);
    String res = template;
    final keys = vars.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (var k in keys) {
      res = res.replaceAll('{$k}', vars[k] ?? "");
    }
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

  void _triggerNextStationBroadcast(BusStation station,
      int terminalOrder,
      Status status,) {
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
    notifyListeners();
    final template = (station.useGlobalNext || station.nextTemplate == null)
        ? Static.settings.nextStationTemplate
        : station.nextTemplate!;
    if (template.isNotEmpty)
      _executeVoice(
        _buildSeq(template, station.name, station.nameEn, isTerminal),
      );
  }

  void _handleLogic(RouteAnalysisResult result,
      Status status,
      List<BusStation> stations,) {
    if (_isOffDutyAlert || _lastDutyStatus != DutyStatus.onDuty) return;

    BusStation? next = result.nextStation;
    if ((next == null || result.isOffRoute) && stations.isNotEmpty) {
      next = stations.first;
    }
    if (next == null) return;

    final int terminalOrder = stations.isNotEmpty ? stations.last.order : -1;
    final double distNext = result.distToNextStation ?? 1000000;
    final double distPrev = result.distToPrevStation ?? 0;

    if ((!result.isOffRoute &&
        (distPrev > 5 &&
            (distPrev > Static.settings.nextStationDepartureDistance ||
                (Static.settings.nextStationDistance >= 0 &&
                    distNext < Static.settings.nextStationDistance)))) ||
        _lastSpokenStationOrder == null) {
      _triggerNextStationBroadcast(next, terminalOrder, status);
    }

    if (!result.isOffRoute &&
        result.distToNextStation != null &&
        Static.settings.arrivalDistance >= 0 &&
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
      notifyListeners();
      if (Static.settings.enableArrivalBroadcast) {
        final template = (next.useGlobalArrival || next.arrivalTemplate == null)
            ? Static.settings.arrivalTemplate
            : next.arrivalTemplate!;
        if (template.isNotEmpty)
          _executeVoice(
            _buildSeq(
              template,
              next.name,
              next.nameEn,
              next.order == terminalOrder,
            ),
          );
      }
    }
  }

  List<Map<String, dynamic>> _buildSeq(List<String> template,
      String name,
      String nameEn,
      bool isTerminal,) {
    bool hasFullAudio = Static.audioManager.hasAudio(name);
    List<String> expanded = [];
    for (var item in template) {
      if (item == "{name}") {
        if (hasFullAudio)
          expanded.add("{name_full}");
        else
          expanded.addAll(Static.settings.stationVoiceSequence);
      } else
        expanded.add(item);
    }
    return expanded
        .map<Map<String, dynamic>>((item) {
      String ak = "",
          tx = "",
          lo = "zh-TW";
      if (item == "{name_full}") {
        ak = name;
        tx = name;
      } else if (item == "{name_zh}") {
        ak = "${name}_國";
        tx = name;
      } else if (item == "{name_en}") {
        ak = "${name}_英";
        tx = nameEn;
        lo = "en-US";
      } else if (item == "{name_ho}") {
        ak = "${name}_閩";
        tx = "";
      } else if (item == "{name_hk}") {
        ak = "${name}_客";
        tx = "";
      } else {
        tx = item
            .replaceAll('{terminal}', isTerminal ? "終點站" : "")
            .replaceAll('{name_zh}', name)
            .replaceAll('{name_ho}', "")
            .replaceAll('{name_hk}', "")
            .replaceAll('{name_en}', nameEn)
            .replaceAll('{name}', name);
        ak = tx;
      }
      return {
        'text': tx,
        'audioKey': ak,
        'locale': lo,
        'speed': (tx == "到了" || tx == "終點站") ? 0.9 : 1.0,
      };
    })
        .where((m) {
      final String ak = m['audioKey'] as String;
      if (ak.endsWith("_閩") || ak.endsWith("_客"))
        return Static.audioManager.hasAudio(ak);
      return ak
          .trim()
          .isNotEmpty ||
          (m['text'] as String)
              .trim()
              .isNotEmpty;
    })
        .toList();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}
