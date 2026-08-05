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
  BusStation? _displayStation;
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

  void update(LatLng? location, double speed, Status status) {
    final now = DateTime.now();
    _speedHistory.add(MapEntry(now, speed));
    _speedHistory.removeWhere((e) => now.difference(e.key).inMinutes > 3);

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

  double _getAverageSpeed() {
    if (_speedHistory.isEmpty) return 0;
    List<double> speeds = _speedHistory.map((e) => e.value).toList()..sort();
    int n = speeds.length;
    int skip = (n * 0.125).floor();
    int take = n - (2 * skip);
    if (take <= 0) return speeds.reduce((a, b) => a + b) / n;
    List<double> filtered = speeds.skip(skip).take(take).toList();
    return filtered.reduce((a, b) => a + b) / filtered.length;
  }

  Map<String, String> getFormattedVariables(LedEvent event, Status status) {
    final now = DateTime.now();
    final avgSpeedKmh = _getAverageSpeed();
    final avgSpeedMs = avgSpeedKmh > 0 ? avgSpeedKmh / 3.6 : 0.0;

    String dest = status.direction == Direction.go
        ? status.route.destination
        : status.route.departure;
    final stations = status.direction == Direction.go
        ? status.route.stations.go
        : status.route.stations.back;

    int idx = -1;
    if (_currentAnalysis?.nextStation != null) {
      idx = stations.indexWhere(
        (s) => s.order == _currentAnalysis!.nextStation!.order,
      );
    }

    Map<String, String> map = {
      'name': event.name,
      'nameEn': event.nameEn,
      'terminal': event.isTerminal ? "終點站" : "",
      'route_name': status.route.name,
      'route_desc': status.route.description ?? "",
      'route_dest': dest,
      'hh': now.hour.toString().padLeft(2, '0'),
      'mm': now.minute.toString().padLeft(2, '0'),
      'ss': now.second.toString().padLeft(2, '0'),
    };

    double distToNext = _currentAnalysis?.distToNextStation ?? 0;
    if (idx != -1 && avgSpeedMs > 0) {
      int currSec = (distToNext / avgSpeedMs).round();
      DateTime currEst = now.add(Duration(seconds: currSec));
      map['currMin'] = (currSec / 60).ceil().toString();
      map['currTimeHH'] = currEst.hour.toString().padLeft(2, '0');
      map['currTimeMM'] = currEst.minute.toString().padLeft(2, '0');
    }

    double cumulativeDist = distToNext;

    for (int i = 1; i <= 15; i++) {
      String pN = "", pE = "", nN = "", nE = "";
      String nMin = "0", nHH = "0", nMM = "0";

      if (idx != -1) {
        if (idx - i >= 0) {
          pN = stations[idx - i].name;
          pE = stations[idx - i].nameEn;
        }
        if (idx + i - 1 < stations.length) {
          final targetIdx = idx + i - 1;
          nN = stations[targetIdx].name;
          nE = stations[targetIdx].nameEn;

          if (i > 1) {
            final s1 = stations[targetIdx - 1];
            final s2 = stations[targetIdx];
            cumulativeDist += const Distance().as(
              LengthUnit.Meter,
              LatLng(s1.lat, s1.lon),
              LatLng(s2.lat, s2.lon),
            );
          }

          if (avgSpeedMs > 0) {
            int totalSec = (cumulativeDist / avgSpeedMs).round();
            DateTime est = now.add(Duration(seconds: totalSec));
            nMin = (totalSec / 60).ceil().toString();
            nHH = est.hour.toString().padLeft(2, '0');
            nMM = est.minute.toString().padLeft(2, '0');
          }
        }
      }
      map['PrevName$i'] = pN;
      map['PrevNameEn$i'] = pE;
      map['NextName$i'] = nN;
      map['NextNameEn$i'] = nE;
      map['NextMin$i'] = nMin;
      map['NextTimeHH$i'] = nHH;
      map['NextTimeMM$i'] = nMM;
    }

    Static.customVariables.forEach((key, template) {
      String processed = template;
      map.forEach((k, v) => processed = processed.replaceAll('{$k}', v));
      map[key] = processed;
    });

    return map;
  }

  String formatTemplate(String template, LedEvent event, Status status) {
    Map<String, String> vars = getFormattedVariables(event, status);
    String res = template;
    vars.forEach((k, v) => res = res.replaceAll('{$k}', v));
    return res;
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
    final int thisId = _activeSequenceId;
    while (_isOffDutyAlert && thisId == _activeSequenceId) {
      try {
        await Static.audioManager.playAssetAndWait("notice.mp3");
      } catch (e) {}
      if (!_isOffDutyAlert) break;
      await Future.delayed(const Duration(milliseconds: 300));
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
      String audioKey = (part['audioKey'] as String).replaceAll("/", "");
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
    _displayStation = station;
    _currentLedEvent = LedEvent(
      type: LedBroadcastType.next,
      name: station.name,
      nameEn: station.nameEn,
      isTerminal: isTerminal,
    );
    notifyListeners();
    final template = (station.useGlobalNext || station.nextTemplate == null)
        ? Static.nextStationTemplate
        : station.nextTemplate!;
    if (template.isNotEmpty)
      _executeVoice(
        _buildSeq(template, station.name, station.nameEn, isTerminal),
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
      final double distNext = result.distToNextStation ?? 1000000000;
      final double distPrev = result.distToPrevStation ?? 0;
      bool canTriggerNext =
          !result.isOffRoute &&
          (distPrev > Static.nextStationDepartureDistance ||
              (Static.nextStationDistance >= 0 &&
                  distNext < Static.nextStationDistance));
      if (canTriggerNext || _lastSpokenStationOrder == null)
        _triggerNextStationBroadcast(nextStation, terminalOrder, status);
      final bool isTerminal = nextStation.order == terminalOrder;
      if (Static.arrivalDistance >= 0 &&
          !result.isOffRoute &&
          distNext < Static.arrivalDistance) {
        if (_lastArrivedStationOrder != nextStation.order) {
          _lastArrivedStationOrder = nextStation.order;
          _displayStation = nextStation;
          _currentLedEvent = LedEvent(
            type: LedBroadcastType.arrival,
            name: nextStation.name,
            nameEn: nextStation.nameEn,
            isTerminal: isTerminal,
          );
          notifyListeners();
          if (Static.enableArrivalBroadcast) {
            final template =
                (nextStation.useGlobalArrival ||
                    nextStation.arrivalTemplate == null)
                ? Static.arrivalTemplate
                : nextStation.arrivalTemplate!;
            if (template.isNotEmpty)
              _executeVoice(
                _buildSeq(
                  template,
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
      } else
        expanded.add(item);
    }
    return expanded
        .map<Map<String, dynamic>>((item) {
          String audioKey = "", text = "", locale = "zh-TW";
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
          if (ak.endsWith("_閩") || ak.endsWith("_客"))
            return Static.audioManager.hasAudio(ak);
          return ak.trim().isNotEmpty ||
              (m['text'] as String).trim().isNotEmpty;
        })
        .toList();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}
