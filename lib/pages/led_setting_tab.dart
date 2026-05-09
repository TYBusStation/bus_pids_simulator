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
          title: const Text("全域 LED 滾動速度", style: TextStyle(fontSize: 14)),
          trailing: SizedBox(
            width: 80,
            child: TextField(
              textAlign: TextAlign.end,
              controller: TextEditingController(
                text: Static.ledScrollSpeed.toStringAsFixed(0),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (s) {
                final n = double.tryParse(s);
                if (n != null) {
                  Static.ledScrollSpeed = n;
                  Static.saveSettings();
                  setState(() {});
                }
              },
            ),
          ),
        ),
        ListTile(
          title: const Text("LED 顯示區域高度", style: TextStyle(fontSize: 14)),
          trailing: SizedBox(
            width: 80,
            child: TextField(
              textAlign: TextAlign.end,
              controller: TextEditingController(
                text: Static.ledHeight.toStringAsFixed(0),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (s) {
                final n = double.tryParse(s);
                if (n != null) {
                  Static.ledHeight = n;
                  Static.saveSettings();
                  setState(() {});
                }
              },
            ),
          ),
        ),
        SwitchListTile(
          title: const Text("顯示即將接近站點標語", style: TextStyle(fontSize: 14)),
          value: Static.showStationListSlogan,
          onChanged: (v) {
            Static.showStationListSlogan = v;
            Static.saveSettings();
            setState(() {});
          },
        ),
        const Divider(),
        SequenceManagerWidget<LedSequence>(
          title: "LED 輪播標語設定",
          items: Static.sloganList,
          onAdd: () => LedSequence(template: "歡迎搭乘"),
          onEdit: (val) async => await _showLedDialog(val, "編輯輪播標語"),
        ),
        SequenceManagerWidget<LedSequence>(
          title: "下站 LED 顯示序列",
          items: Static.ledNextStationSeq,
          onAdd: () => LedSequence(template: "下一站"),
          onEdit: (val) async => await _showLedDialog(val, "編輯下站序列"),
        ),
        SequenceManagerWidget<LedSequence>(
          title: "到站 LED 顯示序列",
          items: Static.ledArrivalSeq,
          onAdd: () => LedSequence(template: "到了"),
          onEdit: (val) async => await _showLedDialog(val, "編輯到站序列"),
        ),
      ],
    );
  }

  Future<LedSequence?> _showLedDialog(LedSequence item, String title) async {
    final tC = TextEditingController(text: item.template);
    final eC = TextEditingController(text: item.entrySpeed.toStringAsFixed(0));
    final sC = TextEditingController(text: item.scrollSpeed.toStringAsFixed(0));
    final dC = TextEditingController(text: item.stayMs.toString());
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
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tC,
                  decoration: const InputDecoration(
                    labelText: "範本内容 (支援 {name}, {nameEn}, {terminal})",
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
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
                        items: LedEntryShort.values
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
                        onChanged: (v) => shortE = v!,
                      ),
                    ),
                    const SizedBox(width: 15),
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
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
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
