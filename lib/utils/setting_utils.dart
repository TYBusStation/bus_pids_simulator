import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/led_sequence.dart';

class FontItem {
  String id, name, type;
  Uint8List? data;

  FontItem({
    required this.id,
    required this.name,
    required this.type,
    this.data,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type};

  factory FontItem.fromJson(Map<String, dynamic> json, Uint8List? data) =>
      FontItem(
        id: json['id'],
        name: json['name'],
        type: json['type'],
        data: data,
      );
}

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() => _instance;

  SettingsService._internal();

  late Box _box, _lottieBox;
  String licensePlate = "KKA-0000", driverId = "000000";
  double globalVolume = 0.7,
      globalSpeed = 1.0,
      arrivalDistance = 100.0,
      nextStationDistance = 250.0,
      nextStationDepartureDistance = 50.0,
      voiceSegmentDelay = 150.0;
  bool enableArrivalBroadcast = true,
      enableArrivalLedBroadcast = true,
      showStationListSlogan = false;
  List<String> stationVoiceSequence = [
        "{name_zh}",
        "{name_ho}",
        "{name_hk}",
        "{name_en}",
      ],
      arrivalTemplate = ["{terminal}", "{name}", "到了"],
      nextStationTemplate = ["下一站", "{terminal}", "{name}"];
  List<LedSequence> sloganList = [
    LedSequence(template: "搭車請招手、上車請刷卡、下車請按鈴"),
    LedSequence(template: "TPASS 2.0 常客優惠，月月領優惠回饋金"),
    LedSequence(
      template: "歡迎搭乘 {route_name} {route_desc} 往 {route_dest} {hh}:{mm}:{ss}",
    ),
  ];
  double ledScrollSpeed = 400.0, ledHeight = 150.0;
  int ledColor = 0xFFFF0000;
  List<String> nextStationListSequence = [
        "即將接近：",
        "{next_stations}",
        "...下車乘客請準備",
      ],
      nextStationSubSequence = ["{name}"];
  int nextStationCount = 5;
  String nextStationSeparator = ">";
  List<LedSequence> ledNextStationSeq = [
    LedSequence(template: "下一站"),
    LedSequence(template: "{terminal}"),
    LedSequence(template: "{name}"),
    LedSequence(template: "{nameEn}"),
  ];
  List<LedSequence> ledArrivalSeq = [
    LedSequence(template: "{name}"),
    LedSequence(template: "{nameEn}"),
    LedSequence(template: "到了"),
  ];
  Uint8List? lottieNext, lottieArrival, lottieSlogan;
  List<FontItem> fontList = [];
  Map<String, String> customVariables = {};
  String lottieOverflowMode = "none";

  dynamic _getSafeData(String key, dynamic defaultValue) {
    final raw = _box.get(key);
    if (raw == null) return defaultValue;

    if (raw is! Map &&
        raw is! List &&
        raw is! String &&
        raw is! num &&
        raw is! bool) {
      try {
        final decoded = jsonDecode(utf8.decode(raw as Uint8List));
        return decoded;
      } catch (e) {
        return defaultValue;
      }
    }
    return raw;
  }

  String? _safeString(dynamic val) {
    if (val == null) return null;
    if (val is String) return val;
    if (val is Uint8List) return utf8.decode(val);
    return val.toString();
  }

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox("settings_box");
    _lottieBox = await Hive.openBox("lottie_data_box");

    licensePlate = _box.get('licensePlate') ?? licensePlate;
    driverId = _box.get('driverId') ?? driverId;
    globalVolume = _box.get('globalVolume') ?? globalVolume;
    globalSpeed = _box.get('globalSpeed') ?? globalSpeed;
    arrivalDistance = _box.get('arrivalDistance') ?? arrivalDistance;
    nextStationDistance =
        _box.get('nextStationDistance') ?? nextStationDistance;
    nextStationDepartureDistance =
        _box.get('nextStationDepartureDistance') ??
        nextStationDepartureDistance;
    voiceSegmentDelay = _box.get('voiceSegmentDelay') ?? voiceSegmentDelay;
    enableArrivalBroadcast =
        _box.get('enableArrivalBroadcast') ?? enableArrivalBroadcast;
    enableArrivalLedBroadcast =
        _box.get('enableArrivalLedBroadcast') ?? enableArrivalLedBroadcast;
    showStationListSlogan =
        _box.get('showStationListSlogan') ?? showStationListSlogan;
    ledScrollSpeed = _box.get('ledScrollSpeed') ?? ledScrollSpeed;
    ledHeight = _box.get('ledHeight') ?? ledHeight;
    ledColor = _box.get('ledColor') ?? ledColor;
    nextStationCount = _box.get('nextStationCount') ?? nextStationCount;
    nextStationSeparator =
        _box.get('nextStationSeparator') ?? nextStationSeparator;
    lottieOverflowMode = _box.get('lottieOverflowMode') ?? lottieOverflowMode;

    stationVoiceSequence = List<String>.from(
      _getSafeData('stationVoiceSequence', stationVoiceSequence),
    );
    arrivalTemplate = List<String>.from(
      _getSafeData('arrivalTemplate', arrivalTemplate),
    );
    nextStationTemplate = List<String>.from(
      _getSafeData('nextStationTemplate', nextStationTemplate),
    );
    nextStationListSequence = List<String>.from(
      _getSafeData('nextStationListSequence', nextStationListSequence),
    );
    nextStationSubSequence = List<String>.from(
      _getSafeData('nextStationSubSequence', nextStationSubSequence),
    );

    final sloganRaw = _safeString(_box.get('sloganList'));
    if (sloganRaw != null) {
      try {
        sloganList = (jsonDecode(sloganRaw) as List)
            .map((e) => LedSequence.fromJson(e))
            .toList();
      } catch (_) {}
    }

    final ledNextRaw = _safeString(_box.get('ledNextStationSeq'));
    if (ledNextRaw != null) {
      try {
        ledNextStationSeq = (jsonDecode(ledNextRaw) as List)
            .map((e) => LedSequence.fromJson(e))
            .toList();
      } catch (_) {}
    }

    final ledArrivalRaw = _safeString(_box.get('ledArrivalSeq'));
    if (ledArrivalRaw != null) {
      try {
        ledArrivalSeq = (jsonDecode(ledArrivalRaw) as List)
            .map((e) => LedSequence.fromJson(e))
            .toList();
      } catch (_) {}
    }

    lottieNext = _lottieBox.get('next');
    lottieArrival = _lottieBox.get('arrival');
    lottieSlogan = _lottieBox.get('slogan');

    final fontMetaRaw = _safeString(_box.get('fontListMetadata'));
    if (fontMetaRaw != null) {
      try {
        List metadata = jsonDecode(fontMetaRaw);
        fontList = metadata.map((m) {
          final fontData = _lottieBox.get('font_data_${m['id']}');
          return FontItem.fromJson(m, fontData is Uint8List ? fontData : null);
        }).toList();
      } catch (_) {}
    }

    final customVarData = _getSafeData('customVariables', null);
    if (customVarData != null && customVarData is Map) {
      customVariables = Map<String, String>.from(customVarData);
    }
  }

  Future<void> save() async {
    await _box.put('licensePlate', licensePlate);
    await _box.put('driverId', driverId);
    await _box.put('globalVolume', globalVolume);
    await _box.put('globalSpeed', globalSpeed);
    await _box.put('arrivalDistance', arrivalDistance);
    await _box.put('nextStationDistance', nextStationDistance);
    await _box.put(
      'nextStationDepartureDistance',
      nextStationDepartureDistance,
    );
    await _box.put('voiceSegmentDelay', voiceSegmentDelay);
    await _box.put('enableArrivalBroadcast', enableArrivalBroadcast);
    await _box.put('enableArrivalLedBroadcast', enableArrivalLedBroadcast);
    await _box.put('stationVoiceSequence', stationVoiceSequence);
    await _box.put('arrivalTemplate', arrivalTemplate);
    await _box.put('nextStationTemplate', nextStationTemplate);
    await _box.put(
      'sloganList',
      jsonEncode(sloganList.map((e) => e.toJson()).toList()),
    );
    await _box.put('showStationListSlogan', showStationListSlogan);
    await _box.put('ledScrollSpeed', ledScrollSpeed);
    await _box.put('ledHeight', ledHeight);
    await _box.put('ledColor', ledColor);
    await _box.put('nextStationListSequence', nextStationListSequence);
    await _box.put('nextStationSubSequence', nextStationSubSequence);
    await _box.put('nextStationCount', nextStationCount);
    await _box.put('nextStationSeparator', nextStationSeparator);
    await _box.put(
      'ledNextStationSeq',
      jsonEncode(ledNextStationSeq.map((e) => e.toJson()).toList()),
    );
    await _box.put(
      'ledArrivalSeq',
      jsonEncode(ledArrivalSeq.map((e) => e.toJson()).toList()),
    );
    await _lottieBox.put('next', lottieNext);
    await _lottieBox.put('arrival', lottieArrival);
    await _lottieBox.put('slogan', lottieSlogan);
    await _box.put('lottieOverflowMode', lottieOverflowMode);
    await _box.put(
      'fontListMetadata',
      jsonEncode(fontList.map((e) => e.toJson()).toList()),
    );
    for (var f in fontList) {
      if (f.type == 'custom') await _lottieBox.put('font_data_${f.id}', f.data);
    }
    await _box.put('customVariables', jsonEncode(customVariables));
    notifyListeners();
  }

  TextStyle getAppFont(String fontFamily, double fontSize, Color color) {
    try {
      final f = fontList.firstWhere(
        (f) => f.id == fontFamily || f.name.split('.').first == fontFamily,
      );
      return TextStyle(fontFamily: f.id, fontSize: fontSize, color: color);
    } catch (_) {
      try {
        return GoogleFonts.getFont(
          fontFamily,
          fontSize: fontSize,
          color: color,
        );
      } catch (_) {
        return GoogleFonts.notoSansTc(fontSize: fontSize, color: color);
      }
    }
  }
}
