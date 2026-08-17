import 'package:flutter/material.dart';

import '../utils/formatter_utils.dart';
import '../utils/static.dart';

class RulesTab extends StatefulWidget {
  const RulesTab({super.key});

  @override
  State<RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<RulesTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SwitchListTile(
          title: const Text("啟用到站報站語音", style: TextStyle(fontSize: 14)),
          value: Static.settings.enableArrivalBroadcast,
          onChanged: (v) {
            setState(() => Static.settings.enableArrivalBroadcast = v);
            Static.saveSettings();
          },
        ),
        const Divider(),
        _dTile(
          "到站報站觸發距離 (公尺)",
          Static.settings.arrivalDistance,
          (v) => Static.settings.arrivalDistance = v,
        ),
        _dTile(
          "下站報站觸發距離 (公尺)",
          Static.settings.nextStationDistance,
          (v) => Static.settings.nextStationDistance = v,
        ),
        const Divider(),
        SequenceManagerWidget<String>(
          title: "站名語音序列元件",
          subtitle: "中文：{name_zh}，閩語：{name_ho}，客語：{name_hk}，英語：{name_en}",
          items: Static.settings.stationVoiceSequence,
          onAdd: () => "{name_zh}",
          onEdit: (val) => FormatterUtils.showTextEditDialog(
            context: context,
            initialValue: val,
          ),
        ),
        SequenceManagerWidget<String>(
          title: "下站報站語音序列",
          subtitle:
              "{name}，中文：{name_zh}，閩語：{name_ho}，客語：{name_hk}，英語：{name_en}，終點站：{terminal}",
          items: Static.settings.nextStationTemplate,
          onAdd: () => "下一站",
          onEdit: (val) => FormatterUtils.showTextEditDialog(
            context: context,
            initialValue: val,
          ),
        ),
        SequenceManagerWidget<String>(
          title: "到站報站語音序列",
          subtitle:
              "{name}，中文：{name_zh}，閩語：{name_ho}，客語：{name_hk}，英語：{name_en}，終點站：{terminal}",
          items: Static.settings.arrivalTemplate,
          onAdd: () => "到了",
          onEdit: (val) => FormatterUtils.showTextEditDialog(
            context: context,
            initialValue: val,
          ),
        ),
      ],
    );
  }

  Widget _dTile(String l, double v, Function(double) cb) {
    return ListTile(
      title: Text(l, style: const TextStyle(fontSize: 14)),
      trailing: SizedBox(
        width: 80,
        child: TextFormField(
          key: ValueKey("${l}_$v"),
          initialValue: v.toStringAsFixed(0),
          textAlign: TextAlign.end,
          keyboardType: TextInputType.number,
          onChanged: (s) {
            final n = double.tryParse(s);
            if (n != null) {
              cb(n);
              Static.saveSettings();
            }
          },
        ),
      ),
    );
  }
}

class SequenceManagerWidget<T> extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<T> items;
  final T Function() onAdd;
  final Future<T?> Function(T) onEdit;

  const SequenceManagerWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  State<SequenceManagerWidget<T>> createState() =>
      _SequenceManagerWidgetState<T>();
}

class _SequenceManagerWidgetState<T> extends State<SequenceManagerWidget<T>> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: widget.subtitle.isEmpty
          ? null
          : Text(widget.subtitle, style: const TextStyle(fontSize: 11)),
      children: [
        ...widget.items.asMap().entries.map(
          (e) => ListTile(
            dense: true,
            title: Text(
              e.value is String
                  ? e.value as String
                  : (e.value as dynamic).template,
              style: const TextStyle(fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final result = await widget.onEdit(e.value);
                    if (result != null)
                      setState(() => widget.items[e.key] = result);
                    Static.saveSettings();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: e.key == 0
                      ? null
                      : () => setState(() {
                          final i = widget.items.removeAt(e.key);
                          widget.items.insert(e.key - 1, i);
                          Static.saveSettings();
                        }),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () => setState(() {
                    widget.items.removeAt(e.key);
                    Static.saveSettings();
                  }),
                ),
              ],
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.add, size: 20),
          title: const Text("新增", style: TextStyle(fontSize: 13)),
          onTap: () => setState(() {
            widget.items.add(widget.onAdd());
            Static.saveSettings();
          }),
        ),
      ],
    );
  }
}
