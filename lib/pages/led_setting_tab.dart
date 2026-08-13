import 'package:flutter/material.dart';

import '../data/led_sequence.dart';
import '../utils/static.dart';
import 'rules_tab.dart';

class LedSettingsTab extends StatefulWidget {
  const LedSettingsTab({super.key});

  @override
  State<LedSettingsTab> createState() => _LedSettingsTabState();
}

class _LedSettingsTabState extends State<LedSettingsTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ListTile(
          title: const Text("全域字幕滾動速度", style: TextStyle(fontSize: 14)),
          trailing: SizedBox(
            width: 80,
            child: TextField(
              textAlign: TextAlign.end,
              controller: TextEditingController(
                text: Static.settings.ledScrollSpeed.toStringAsFixed(0),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (s) {
                final n = double.tryParse(s);
                if (n != null) {
                  Static.settings.ledScrollSpeed = n;
                  Static.saveSettings();
                  setState(() {});
                }
              },
            ),
          ),
        ),
        ListTile(
          title: const Text("全域字幕顏色", style: TextStyle(fontSize: 14)),
          subtitle: const Text(
            "紅色：FFFF0000，螢光綠：FFEDFA00",
            style: TextStyle(fontSize: 12),
          ),
          trailing: SizedBox(
            width: 100,
            child: TextField(
              textAlign: TextAlign.end,
              controller: TextEditingController(
                text: Static.settings.ledColor.toRadixString(16).toUpperCase(),
              ),
              onSubmitted: (s) {
                final n = int.tryParse(s, radix: 16);
                if (n != null) {
                  Static.settings.ledColor = n;
                  Static.saveSettings();
                  setState(() {});
                }
              },
            ),
          ),
        ),
        ListTile(
          title: const Text("字幕顯示區域高度", style: TextStyle(fontSize: 14)),
          trailing: SizedBox(
            width: 80,
            child: TextField(
              textAlign: TextAlign.end,
              controller: TextEditingController(
                text: Static.settings.ledHeight.toStringAsFixed(0),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (s) {
                final n = double.tryParse(s);
                if (n != null) {
                  Static.settings.ledHeight = n;
                  Static.saveSettings();
                  setState(() {});
                }
              },
            ),
          ),
        ),
        ExpansionTile(
          title: const Text(
            "即將接近字幕設定",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          children: [
            SwitchListTile(
              title: const Text("顯示即將接近字幕", style: TextStyle(fontSize: 14)),
              value: Static.settings.showStationListSlogan,
              onChanged: (v) {
                Static.settings.showStationListSlogan = v;
                Static.saveSettings();
                setState(() {});
              },
            ),
            SequenceManagerWidget<String>(
              title: "即將接近字幕序列",
              subtitle: "站名串接列表：{next_stations}",
              items: Static.settings.nextStationListSequence,
              onAdd: () => "{next_stations}",
              onEdit: (val) async => await _showTextDialog(val),
            ),
            ExpansionTile(
              title: const Text(
                "{next_stations}",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              children: [
                SequenceManagerWidget<String>(
                  title: "單站顯示",
                  subtitle:
                      "中文：{name}，英文：{nameEn}，預估分鐘：{Min}，預估時間時：{TimeHH}，預估時間分：{TimeMM}",
                  items: Static.settings.nextStationSubSequence,
                  onAdd: () => "{TimeHH}:{TimeMM}{name}",
                  onEdit: (val) async => await _showTextDialog(val),
                ),
                ListTile(
                  title: const Text(
                    "顯示站數、連接符號",
                    style: TextStyle(fontSize: 14),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        child: TextField(
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: Static.settings.nextStationCount.toString(),
                          ),
                          onSubmitted: (v) {
                            Static.settings.nextStationCount =
                                int.tryParse(v) ?? 5;
                            Static.saveSettings();
                            setState(() {});
                          },
                        ),
                      ),
                      const Text("、"),
                      SizedBox(
                        width: 40,
                        child: TextField(
                          textAlign: TextAlign.center,
                          controller: TextEditingController(
                            text: Static.settings.nextStationSeparator,
                          ),
                          onSubmitted: (v) {
                            Static.settings.nextStationSeparator = v;
                            Static.saveSettings();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        SequenceManagerWidget<LedSequence>(
          title: "字幕輪播標語設定",
          subtitle: "",
          items: Static.settings.sloganList,
          onAdd: () => LedSequence(template: "歡迎搭乘"),
          onEdit: (val) async => await _showLedDialog(val, "編輯輪播標語"),
        ),
        SequenceManagerWidget<LedSequence>(
          title: "下站字幕顯示序列",
          subtitle: "中文：{name}，英文：{nameEn}，終點站：{terminal}",
          items: Static.settings.ledNextStationSeq,
          onAdd: () => LedSequence(template: "下一站"),
          onEdit: (val) async => await _showLedDialog(val, "編輯下站序列"),
        ),
        SequenceManagerWidget<LedSequence>(
          title: "到站字幕顯示序列",
          subtitle: "中文：{name}，英文：{nameEn}，終點站：{terminal}",
          items: Static.settings.ledArrivalSeq,
          onAdd: () => LedSequence(template: "到了"),
          onEdit: (val) async => await _showLedDialog(val, "編輯到站序列"),
        ),
      ],
    );
  }

  Future<String?> _showTextDialog(String initial) async {
    final c = TextEditingController(text: initial);
    return await showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("編輯片段", style: TextStyle(fontSize: 16)),
        content: TextField(controller: c, autofocus: true),
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
  }

  Future<LedSequence?> _showLedDialog(LedSequence item, String title) async {
    final tC = TextEditingController(text: item.template);
    final eC = TextEditingController(text: item.entrySpeed.toStringAsFixed(0));
    final sC = TextEditingController(text: item.scrollSpeed.toStringAsFixed(0));
    final dC = TextEditingController(text: item.stayMs.toString());
    final cC = TextEditingController(
      text: item.color.toRadixString(16).toUpperCase(),
    );

    LedEntryShort shortE = item.entryShort;
    LedEntryLong longE = item.entryLong;

    return await showDialog<LedSequence>(
      context: context,
      builder: (v) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                            label = "跟隨長文字行為 (強制滾動)";

                          return DropdownMenuItem(
                            value: v,
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => shortE = v!,
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
                        onChanged: (v) => longE = v!,
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
                Row(children: []),
                const SizedBox(height: 10),
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
              item.template = tC.text;
              item.entryShort = shortE;
              item.entryLong = longE;
              item.entrySpeed = double.tryParse(eC.text) ?? 500;
              item.scrollSpeed = double.tryParse(sC.text) ?? 400;
              item.stayMs = int.tryParse(dC.text) ?? 800;
              item.color = int.tryParse(cC.text) ?? 0xFFFF0000;
              Static.saveSettings();
              Navigator.pop(v, item);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }
}
