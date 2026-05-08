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
        SequenceManagerWidget<String>(
          title: "LED 輪播標語設定",
          items: Static.sloganList,
          onAdd: () => "歡迎搭乘",
          onEdit: (val) async => await _showTextDialog(val),
        ),
        SequenceManagerWidget<LedSequence>(
          title: "下站 LED 顯示序列",
          items: Static.ledNextStationSeq,
          onAdd: () => LedSequence(template: "下一站"),
          onEdit: (val) async => await _showLedDialog(val),
        ),
        SequenceManagerWidget<LedSequence>(
          title: "到站 LED 顯示序列",
          items: Static.ledArrivalSeq,
          onAdd: () => LedSequence(template: "到了"),
          onEdit: (val) async => await _showLedDialog(val),
        ),
      ],
    );
  }

  Future<String?> _showTextDialog(String initial) async {
    final c = TextEditingController(text: initial);
    return await showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("編輯標語"),
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

  Future<LedSequence?> _showLedDialog(LedSequence item) async {
    final tC = TextEditingController(text: item.template);
    final eC = TextEditingController(text: item.entrySpeed.toStringAsFixed(0));
    final sC = TextEditingController(text: item.scrollSpeed.toStringAsFixed(0));
    final dC = TextEditingController(text: item.stayMs.toString());
    LedEntryShort shortE = item.entryShort;
    LedEntryLong longE = item.entryLong;

    return await showDialog<LedSequence>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("編輯 LED 片段"),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 20,
              runSpacing: 16,
              children: [
                _box(
                  260,
                  TextField(
                    controller: tC,
                    decoration: const InputDecoration(labelText: "範本"),
                  ),
                ),
                _box(
                  260,
                  DropdownButtonFormField<LedEntryShort>(
                    value: shortE,
                    decoration: const InputDecoration(labelText: "短文字進入方式"),
                    items: LedEntryShort.values
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text(v.name)),
                        )
                        .toList(),
                    onChanged: (v) => shortE = v!,
                  ),
                ),
                _box(
                  260,
                  DropdownButtonFormField<LedEntryLong>(
                    value: longE,
                    decoration: const InputDecoration(labelText: "長文字進入方式"),
                    items: LedEntryLong.values
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text(v.name)),
                        )
                        .toList(),
                    onChanged: (v) => longE = v!,
                  ),
                ),
                _box(
                  120,
                  TextField(
                    controller: eC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "進入耗時"),
                  ),
                ),
                _box(
                  120,
                  TextField(
                    controller: sC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "滾動速度"),
                  ),
                ),
                _box(
                  120,
                  TextField(
                    controller: dC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "停留時間"),
                  ),
                ),
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
              Navigator.pop(v, item);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  Widget _box(double w, Widget child) => SizedBox(
    width: w,
    child: Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
  );
}
