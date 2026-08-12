import 'package:flutter/material.dart';

import '../utils/static.dart';

class VariableSettingTab extends StatefulWidget {
  const VariableSettingTab({super.key});

  @override
  State<VariableSettingTab> createState() => _VariableSettingTabState();
}

class _VariableSettingTabState extends State<VariableSettingTab> {
  final List<String> _builtinBasics = [
    "{name} - 當前站名",
    "{nameEn} - 當前站名英文",
    "{currMin} - 當前站預估分鐘",
    "{currTimeHH} - 當前站預估時間時",
    "{currTimeMM} - 當前站預估時間分",
    "{terminal} - 終點站時為\"終點站\"，否則為(空白)",
    "{route_name} - 當前路線名稱",
    "{route_nameEn} - 當前路線名稱英文",
    "{route_desc} - 當前路線描述",
    "{route_descEn} - 當前路線描述英文",
    "{route_dest} - 當前路線目的地",
    "{route_destEn} - 當前路線目的地英文",
    "{route_dep} - 當前路線起點",
    "{route_depEn} - 當前路線起點英文",
    "{hh} - 當前時間小時",
    "{mm} - 當前時間分鐘",
    "{ss} - 當前時間秒數",
  ];

  final List<String> _builtinIndexed = [
    "{NextMinΨ} - 下Ψ站預估分鐘",
    "{NextTimeHHΨ} - 下Ψ站預估時間時",
    "{NextTimeMMΨ} - 下Ψ站預估時間分",
    "{NextNameΨ} - 下Ψ站站名",
    "{NextNameEnΨ} - 下Ψ站站名英文",
    "{PrevNameΨ} - 前Ψ站站名",
    "{PrevNameEnΨ} - 前Ψ站站名英文",
    "其中 Ψ 可為 1 - 15，如 {NextMin1}",
  ];

  void _showVarDialog({String? editKey, String? editVal}) async {
    String key = editKey ?? "";
    String val = editVal ?? "";
    bool isEdit = editKey != null;

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isEdit ? "修改自訂變數" : "新增自訂變數"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: key),
              enabled: !isEdit,
              decoration: InputDecoration(labelText: "變數名稱"),
              onChanged: (v) => key = v,
            ),
            TextField(
              controller: TextEditingController(text: val),
              decoration: const InputDecoration(labelText: "格式化字串"),
              onChanged: (v) => val = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              if (key.isNotEmpty) {
                Static.settings.customVariables[key] = val;
                Static.saveSettings();
                setState(() {});
              }
              Navigator.pop(c);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "基本變數",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _builtinBasics
              .map(
                (e) => Chip(
                  label: Text(e, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.blueGrey.shade900,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          "站牌變數",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _builtinIndexed
              .map(
                (e) => Chip(
                  label: Text(e, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.indigo.shade900,
                ),
              )
              .toList(),
        ),
        const Divider(height: 40),
        const Text("可於遠端語音頁面下載範例並匯入"),
        const Divider(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "自定義變數",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ElevatedButton.icon(
              onPressed: () => _showVarDialog(),
              icon: const Icon(Icons.add),
              label: const Text("新增"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (Static.settings.customVariables.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text("尚未新增自定義變數", style: TextStyle(color: Colors.grey)),
            ),
          ),
        ...Static.settings.customVariables.entries.map(
          (e) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                "{${e.key}}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              subtitle: Text(e.value),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () =>
                        _showVarDialog(editKey: e.key, editVal: e.value),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(
                        () => Static.settings.customVariables.remove(e.key),
                      );
                      Static.saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
