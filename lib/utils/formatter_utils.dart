import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/bus_route.dart';
import '../data/led_sequence.dart';

abstract class FormatterUtils {
  static final DateFormat apiTimeFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");
  static final DateFormat apiDateFormat = DateFormat("yyyy-MM-dd");
  static final DateFormat displayTimeFormatNoSec = DateFormat(
    'yyyy-MM-dd HH:mm',
  );
  static final DateFormat displayTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat displayDateFormat = DateFormat('yyyy/MM/dd');
  static final RegExp letterNumber = RegExp(r"[^a-zA-Z0-9]");

  static Map<String, dynamic> _parseRoute(String route) {
    String type = 'UNKNOWN';
    int? baseNum;
    String? baseStr;
    String suffixAlpha = '',
        suffixNumeric = '',
        suffixSpecial = '',
        suffixParenthesis = '';
    String mainPart = route;
    if (route.contains('(')) {
      final match = RegExp(r'^(.*?)\((.*)\)$').firstMatch(route);
      if (match != null) {
        mainPart = match.group(1)!;
        suffixParenthesis = '(${match.group(2)!})';
      }
    }
    RegExpMatch? specialPrefixMatch = RegExp(
      r'^(\d+)([東西南北])$',
    ).firstMatch(mainPart);
    if (specialPrefixMatch != null) {
      type = 'SPECIAL_PREFIX';
      baseNum = int.tryParse(specialPrefixMatch.group(1)!);
      suffixSpecial = specialPrefixMatch.group(2)!;
    } else if (mainPart.startsWith('T')) {
      type = 'T';
      RegExpMatch? match = RegExp(r'^T(\d+)([A-Z]*)').firstMatch(mainPart);
      if (match != null) {
        baseNum = int.tryParse(match.group(1)!);
        suffixAlpha = match.group(2) ?? '';
      } else {
        type = 'ALPHA';
        baseStr = mainPart;
      }
    } else if (RegExp(r'^\d').hasMatch(mainPart)) {
      type = 'NUMERIC';
      RegExpMatch? match = RegExp(r'^(\d+)(.*)').firstMatch(mainPart);
      if (match != null) {
        baseNum = int.tryParse(match.group(1)!);
        String remaining = match.group(2) ?? '';
        RegExpMatch? suffixMatch = RegExp(
          r'^([A-Z]*)(.*)',
        ).firstMatch(remaining);
        if (suffixMatch != null) {
          suffixAlpha = suffixMatch.group(1) ?? '';
          suffixSpecial = suffixMatch.group(2) ?? '';
        }
      }
    } else {
      type = 'ALPHA';
      RegExpMatch? match = RegExp(
        r'^([A-Z]+)(\d*)([A-Z]*)(.*)',
      ).firstMatch(mainPart);
      if (match != null) {
        baseStr = match.group(1)!;
        suffixNumeric = match.group(2) ?? '';
        suffixAlpha = match.group(3) ?? '';
        suffixSpecial = match.group(4) ?? '';
      } else {
        baseStr = mainPart;
      }
    }
    return {
      'original': route,
      'type': type,
      'baseNum': baseNum,
      'baseStr': baseStr,
      'suffixAlpha': suffixAlpha,
      'suffixNumeric': suffixNumeric,
      'suffixSpecial': suffixSpecial,
      'suffixParenthesis': suffixParenthesis,
    };
  }

  static int compareRoutes(String a, String b) {
    if (a == b) return 0;
    var pa = _parseRoute(a);
    var pb = _parseRoute(b);
    int typeOrder(String type) {
      if (type == 'SPECIAL_PREFIX') return 0;
      if (type == 'NUMERIC') return 1;
      if (type == 'ALPHA') return 2;
      if (type == 'T') return 3;
      return 4;
    }

    int typeComparison = typeOrder(pa['type']).compareTo(typeOrder(pb['type']));
    if (typeComparison != 0) return typeComparison;
    if (pa['baseNum'] != null && pb['baseNum'] != null) {
      int baseNumComparison = pa['baseNum'].compareTo(pb['baseNum']);
      if (baseNumComparison != 0) return baseNumComparison;
    } else if (pa['baseStr'] != null && pb['baseStr'] != null) {
      int baseStrComparison = (pa['baseStr'] ?? '').compareTo(
        pb['baseStr'] ?? '',
      );
      if (baseStrComparison != 0) return baseStrComparison;
    }
    int getSpecialSuffixOrder(String suffix) {
      if (suffix.isEmpty) return 0;
      if (suffix == '區') return 1;
      if (suffix == '副') return 2;
      if (suffix == '直') return 3;
      if (suffix == '快') return 4;
      if (suffix == '夜') return 5;
      if (suffix == '通勤') return 6;
      if (suffix == '延') return 7;
      if (suffix.startsWith('經')) return 8;
      return 99;
    }

    if ((pa['suffixAlpha'] as String).compareTo(pb['suffixAlpha'] as String) !=
        0)
      return (pa['suffixAlpha'] as String).compareTo(
        pb['suffixAlpha'] as String,
      );
    int specialSuffixComparison = getSpecialSuffixOrder(
      pa['suffixSpecial'] as String,
    ).compareTo(getSpecialSuffixOrder(pb['suffixSpecial'] as String));
    if (specialSuffixComparison != 0) return specialSuffixComparison;
    if ((pa['suffixSpecial'] as String).compareTo(
          pb['suffixSpecial'] as String,
        ) !=
        0)
      return (pa['suffixSpecial'] as String).compareTo(
        pb['suffixSpecial'] as String,
      );
    int paSuffixNumVal = (pa['suffixNumeric'] as String).isEmpty
        ? 0
        : int.parse(pa['suffixNumeric'] as String);
    int pbSuffixNumVal = (pb['suffixNumeric'] as String).isEmpty
        ? 0
        : int.parse(pb['suffixNumeric'] as String);
    if (paSuffixNumVal.compareTo(pbSuffixNumVal) != 0)
      return paSuffixNumVal.compareTo(pbSuffixNumVal);
    return (pa['suffixParenthesis'] as String).compareTo(
      pb['suffixParenthesis'] as String,
    );
  }

  static String getBusDirectionName(BusRoute route, int goBack) {
    if (route.destination.isEmpty && route.departure.isEmpty) return '未知';
    return goBack == 1
        ? route.destination
        : (goBack == 2 ? route.departure : '未知');
  }

  static void showSnackbar(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Color? color,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        showCloseIcon: true,
        duration: const Duration(seconds: 3),
        action: action,
        backgroundColor: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }

  static Future<void> registerCustomFont(
    String familyName,
    Uint8List bytes,
  ) async {
    final fontLoader = FontLoader(familyName);
    fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await fontLoader.load();
  }

  static Future<String?> showTextEditDialog({
    required BuildContext context,
    required String initialValue,
    String title = "編輯片段",
  }) async {
    final c = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: "內容"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(v),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(v, c.text),
            child: const Text("確定"),
          ),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  static Future<LedSequence?> showLedEditDialog({
    required BuildContext context,
    required LedSequence item,
    String title = "編輯字幕序列",
  }) async {
    final tC = TextEditingController(text: item.template);
    final eC = TextEditingController(text: item.entrySpeed.toStringAsFixed(0));
    final sC = TextEditingController(text: item.scrollSpeed.toStringAsFixed(0));
    final dC = TextEditingController(text: item.stayMs.toString());
    final cC = TextEditingController(
      text: item.color.toRadixString(16).toUpperCase(),
    );

    LedEntryShort shortE = item.entryShort;
    LedEntryLong longE = item.entryLong;

    final result = await showDialog<LedSequence>(
      context: context,
      builder: (v) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          title: Text(title, style: const TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tC,
                          decoration: const InputDecoration(
                            labelText: "內容",
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: cC,
                          decoration: const InputDecoration(
                            labelText: "顏色",
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<LedEntryShort>(
                          value: shortE,
                          decoration: const InputDecoration(
                            labelText: "短文字進入",
                            isDense: true,
                          ),
                          items: LedEntryShort.values.map((v) {
                            String label = v.name;
                            if (v == LedEntryShort.asLongSetting)
                              label = "長文字行為";
                            return DropdownMenuItem(
                              value: v,
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => shortE = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<LedEntryLong>(
                          value: longE,
                          decoration: const InputDecoration(
                            labelText: "長文字進入",
                            isDense: true,
                          ),
                          items: LedEntryLong.values
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                    v.name,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => longE = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: eC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "進入耗時(ms)",
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: sC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "滾動速度",
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: dC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "停留(ms)",
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(v),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () {
                final newItem = item.copyWith(
                  template: tC.text,
                  entryShort: shortE,
                  entryLong: longE,
                  entrySpeed: double.tryParse(eC.text) ?? 500,
                  scrollSpeed: double.tryParse(sC.text) ?? 400,
                  stayMs: int.tryParse(dC.text) ?? 800,
                  color: int.tryParse(cC.text, radix: 16) ?? 0xFFFF0000,
                );
                Navigator.pop(v, newItem);
              },
              child: const Text("確定"),
            ),
          ],
        ),
      ),
    );
    tC.dispose();
    eC.dispose();
    sC.dispose();
    dC.dispose();
    cC.dispose();
    return result;
  }
}
