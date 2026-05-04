import 'package:flutter/material.dart';

import '../utils/static.dart';
import 'audio_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          elevation: 0,
          bottom: const TabBar(
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: "報站規則"),
              Tab(text: "語音管理"),
            ],
          ),
        ),
        body: const TabBarView(children: [_RulesTab(), AudioPage()]),
      ),
    );
  }
}

class _RulesTab extends StatefulWidget {
  const _RulesTab();

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        _dTile(
          "到站報站觸發：離下站距離(公尺) [負數則無法觸發]",
          Static.arrivalDistance,
          (v) => Static.arrivalDistance = v,
        ),
        _dTile(
          "下站報站觸發：離下站距離(公尺) [與下方擇一觸發]",
          Static.nextStationDistance,
          (v) => Static.nextStationDistance = v,
        ),
        _dTile(
          "下站報站觸發：離上站距離(公尺) [與上方擇一觸發]",
          Static.nextStationDepartureDistance,
          (v) => Static.nextStationDepartureDistance = v,
        ),
        const Divider(),
        _ruleExp("下站報站文字序列", Static.nextStationTemplate),
        _ruleExp("到站報站文字序列", Static.arrivalTemplate),
      ],
    );
  }

  Widget _dTile(String l, double v, Function(double) cb) {
    return ListTile(
      dense: true,
      title: Text(l, style: const TextStyle(fontSize: 14)),
      trailing: SizedBox(
        width: 60,
        child: TextField(
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 14),
          controller: TextEditingController(text: v.toStringAsFixed(0)),
          keyboardType: TextInputType.number,
          onSubmitted: (s) {
            final n = double.tryParse(s);
            if (n != null) {
              setState(() => cb(n));
              Static.saveSettings();
            }
          },
        ),
      ),
    );
  }

  Widget _ruleExp(String t, List<String> l) {
    return ExpansionTile(
      title: Text(
        t,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      tilePadding: EdgeInsets.zero,
      children: [
        ...l.asMap().entries.map(
          (e) => ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 12),
            title: Text(e.value, style: const TextStyle(fontSize: 13)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () => _showEditDialog(l, e.key),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  onPressed: e.key == 0
                      ? null
                      : () {
                          setState(() {
                            final i = l.removeAt(e.key);
                            l.insert(e.key - 1, i);
                          });
                          Static.saveSettings();
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: () {
                    setState(() => l.removeAt(e.key));
                    Static.saveSettings();
                  },
                ),
              ],
            ),
          ),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.add, size: 18),
          title: const Text("新增片段", style: TextStyle(fontSize: 13)),
          onTap: () => _showAddDialog(l),
        ),
      ],
    );
  }

  void _showEditDialog(List<String> l, int index) {
    final c = TextEditingController(text: l[index]);
    showDialog(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("編輯內容"),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(v),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              if (c.text.isNotEmpty) {
                setState(() => l[index] = c.text);
                Static.saveSettings();
              }
              Navigator.pop(v);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(List<String> l) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("新增內容"),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(v),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              if (c.text.isNotEmpty) {
                setState(() => l.add(c.text));
                Static.saveSettings();
              }
              Navigator.pop(v);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }
}
