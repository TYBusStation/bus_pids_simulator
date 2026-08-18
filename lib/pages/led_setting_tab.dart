import 'package:bus_pids_simulator/utils/formatter_utils.dart';
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
        SwitchListTile(
          title: const Text("啟用到站字幕顯示", style: TextStyle(fontSize: 14)),
          value: Static.settings.enableArrivalLedBroadcast,
          onChanged: (v) {
            Static.settings.enableArrivalLedBroadcast = v;
            Static.saveSettings();
            setState(() {});
          },
        ),
        const Divider(),
        _buildTextField(
          "全域字幕滾動速度",
          Static.settings.ledScrollSpeed.toStringAsFixed(0),
              (v) {
            Static.settings.ledScrollSpeed = double.tryParse(v) ?? 400;
          },
        ),
        _buildTextField(
          "全域字幕顏色 (HEX)",
          Static.settings.ledColor.toRadixString(16).toUpperCase(),
              (v) {
            Static.settings.ledColor = int.tryParse(v, radix: 16) ?? 0xFFFF0000;
          },
        ),
        _buildTextField(
          "字幕顯示區域高度",
          Static.settings.ledHeight.toStringAsFixed(0),
              (v) {
            Static.settings.ledHeight = double.tryParse(v) ?? 150;
          },
        ),
        const Divider(),
        ExpansionTile(
          title: const Text(
            "即將接近字幕設定",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          children: [
            SwitchListTile(
              title: const Text(
                  "顯示即將接近字幕標語", style: TextStyle(fontSize: 14)),
              value: Static.settings.showStationListSlogan,
              onChanged: (v) {
                Static.settings.showStationListSlogan = v;
                Static.saveSettings();
                setState(() {});
              },
            ),
            SequenceManagerWidget<LedSequence>(
              title: "字幕輪播標語設定",
              subtitle: "於即將接近時循環顯示之文字",
              items: Static.settings.sloganList,
              onAdd: () => LedSequence(template: "歡迎搭乘"),
              onEdit: (val) =>
                  FormatterUtils.showLedEditDialog(
                    context: context,
                    item: val,
                    title: "編輯輪播標語",
                  ),
            ),
            ExpansionTile(
              title: const Text(
                "{next_stations} 多站清單設定",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              children: [
                SequenceManagerWidget<String>(
                  title: "單站顯示格式",
                  subtitle: "中文：{name}，英文：{nameEn}，預估分鐘：{Min}，預估時間時：{TimeHH}，預估時間分：{TimeMM}",
                  items: Static.settings.nextStationSubSequence,
                  onAdd: () => "{TimeHH}:{TimeMM} {name}",
                  onEdit: (val) =>
                      FormatterUtils.showTextEditDialog(
                        context: context,
                        initialValue: val,
                      ),
                ),
                ListTile(
                  title: const Text(
                      "顯示站數、連接符號", style: TextStyle(fontSize: 14)),
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
                            Static.settings.nextStationCount = int.tryParse(
                                v) ?? 5;
                            Static.saveSettings();
                            setState(() {});
                          },
                        ),
                      ),
                      const Text(" 站，符號: "),
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
                            setState(() {});
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
        const Divider(),
        SequenceManagerWidget<LedSequence>(
          title: "下站字幕顯示序列",
          subtitle: "中文：{name}，英文：{nameEn}，終點站：{terminal}",
          items: Static.settings.ledNextStationSeq,
          onAdd: () => LedSequence(template: "下一站"),
          onEdit: (val) =>
              FormatterUtils.showLedEditDialog(
                context: context,
                item: val,
                title: "編輯下站序列",
              ),
        ),
        SequenceManagerWidget<LedSequence>(
          title: "到站字幕顯示序列",
          subtitle: "中文：{name}，英文：{nameEn}，終點站：{terminal}",
          items: Static.settings.ledArrivalSeq,
          onAdd: () => LedSequence(template: "到了"),
          onEdit: (val) =>
              FormatterUtils.showLedEditDialog(
                context: context,
                item: val,
                title: "編輯到站序列",
              ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label,
      String initial,
      Function(String) onSave,) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: SizedBox(
        width: 100,
        child: TextField(
          textAlign: TextAlign.end,
          controller: TextEditingController(text: initial),
          style: const TextStyle(fontSize: 13),
          onSubmitted: (v) {
            onSave(v);
            Static.saveSettings();
            setState(() {});
          },
        ),
      ),
    );
  }
}