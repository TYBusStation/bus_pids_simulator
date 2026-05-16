import 'package:flutter/material.dart';

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
          value: Static.enableArrivalBroadcast,
          onChanged: (v) {
            setState(() {
              Static.enableArrivalBroadcast = v;
            });
            Static.saveSettings();
          },
        ),
        const Divider(),
        _dTile(
          "到站報站觸發距離 (公尺)",
          Static.arrivalDistance,
          (v) => Static.arrivalDistance = v,
        ),
        _dTile(
          "下站報站觸發距離 (公尺)",
          Static.nextStationDistance,
          (v) => Static.nextStationDistance = v,
        ),
        _dTile(
          "下站離開上站觸發距離 (公尺)",
          Static.nextStationDepartureDistance,
          (v) => Static.nextStationDepartureDistance = v,
        ),
        const Divider(height: 32),
        SequenceManagerWidget<String>(
          title: "{name}",
          items: Static.stationVoiceSequence,
          onAdd: () => "{name_zh}",
          onEdit: (val) async => await _showTextDialog(
            val,
            "可用參數：\n{name_zh} - 中文\n{name_ho} - 台語\n{name_hk} - 客語\n{name_en} - 英文",
          ),
        ),
        SequenceManagerWidget<String>(
          title: "下站報站語音序列",
          items: Static.nextStationTemplate,
          onAdd: () => "下一站",
          onEdit: (val) async => await _showTextDialog(
            val,
            "可用參數：\n{name} - 引用上方定義的完整序列\n{name_zh} - 中文\n{name_ho} - 台語\n{name_hk} - 客語\n{name_en} - 英文\n{terminal} - 「終點站」字樣",
          ),
        ),
        SequenceManagerWidget<String>(
          title: "到站報站語音序列",
          items: Static.arrivalTemplate,
          onAdd: () => "到了",
          onEdit: (val) async => await _showTextDialog(
            val,
            "可用參數：\n{name} - 引用上方定義的完整序列\n{name_zh} - 中文\n{name_ho} - 台語\n{name_hk} - 客語\n{name_en} - 英文\n{terminal} - 「終點站」字樣",
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
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          ),
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

  Future<String?> _showTextDialog(String initial, String hint) async {
    final c = TextEditingController(text: initial);
    return await showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("編輯片段"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(labelText: "內容"),
            ),
            const SizedBox(height: 16),
            Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
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
  }
}

class SequenceManagerWidget<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T Function() onAdd;
  final Future<T?> Function(T) onEdit;

  const SequenceManagerWidget({
    super.key,
    required this.title,
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
      children: [
        ...widget.items.asMap().entries.map(
          (e) => ListTile(
            dense: true,
            title: Text(
              e.value is String
                  ? e.value as String
                  : (e.value as dynamic).template,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final result = await widget.onEdit(e.value);
                    if (result != null) {
                      setState(() {
                        widget.items[e.key] = result;
                      });
                      Static.saveSettings();
                    }
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
          leading: const Icon(Icons.add),
          title: const Text("新增"),
          onTap: () => setState(() {
            widget.items.add(widget.onAdd());
            Static.saveSettings();
          }),
        ),
      ],
    );
  }
}
