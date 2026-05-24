import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/bus_station.dart';

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
                        }),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () => setState(() {
                    widget.items.removeAt(e.key);
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
          }),
        ),
      ],
    );
  }
}

class StationDialog extends StatefulWidget {
  final LatLng point;
  final BusStation? existing;
  final List<BusStation> currentList;

  const StationDialog({
    super.key,
    required this.point,
    this.existing,
    required this.currentList,
  });

  @override
  State<StationDialog> createState() => _StationDialogState();
}

class _StationDialogState extends State<StationDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _orderCtrl;
  late List<String> _nextTpl;
  late List<String> _arrTpl;
  bool _useGlobalNext = true;
  bool _useGlobalArrival = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? "");
    _nameEnCtrl = TextEditingController(text: widget.existing?.nameEn ?? "");
    _orderCtrl = TextEditingController(
      text: (widget.currentList.length + 1).toString(),
    );
    _nextTpl = List.from(widget.existing?.nextTemplate ?? ["下一站", "{name}"]);
    _arrTpl = List.from(widget.existing?.arrivalTemplate ?? ["{name}", "到了"]);
    _useGlobalNext = widget.existing?.useGlobalNext ?? true;
    _useGlobalArrival = widget.existing?.useGlobalArrival ?? true;
  }

  Future<String?> _showTextDialog(String initial) async {
    final c = TextEditingController(text: initial);
    return await showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("編輯片段"),
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

  @override
  Widget build(BuildContext context) {
    bool isExist = widget.currentList.any(
      (s) => s.lat == widget.point.latitude && s.lon == widget.point.longitude,
    );

    return AlertDialog(
      title: const Text("站點設定", style: TextStyle(fontSize: 14)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "站名"),
              ),
              TextField(
                controller: _nameEnCtrl,
                decoration: const InputDecoration(labelText: "英文站名"),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text("下一站同步全域", style: TextStyle(fontSize: 12)),
                value: _useGlobalNext,
                onChanged: (v) => setState(() => _useGlobalNext = v),
                dense: true,
              ),
              if (!_useGlobalNext)
                SequenceManagerWidget<String>(
                  title: "自訂下一站序列",
                  items: _nextTpl,
                  onAdd: () => "下一站",
                  onEdit: (val) => _showTextDialog(val),
                ),
              SwitchListTile(
                title: const Text("到站同步全域", style: TextStyle(fontSize: 12)),
                value: _useGlobalArrival,
                onChanged: (v) => setState(() => _useGlobalArrival = v),
                dense: true,
              ),
              if (!_useGlobalArrival)
                SequenceManagerWidget<String>(
                  title: "自訂到站序列",
                  items: _arrTpl,
                  onAdd: () => "到了",
                  onEdit: (val) => _showTextDialog(val),
                ),
              const Divider(),
              TextField(
                controller: _orderCtrl,
                decoration: const InputDecoration(labelText: "順序"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isExist)
          TextButton(
            onPressed: () => Navigator.pop(context, {'action': 'delete'}),
            child: const Text("移除", style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("取消"),
        ),
        ElevatedButton(
          onPressed: () {
            final s = BusStation(
              order: 0,
              name: _nameCtrl.text,
              nameEn: _nameEnCtrl.text,
              lat: widget.point.latitude,
              lon: widget.point.longitude,
              useGlobalNext: _useGlobalNext,
              useGlobalArrival: _useGlobalArrival,
              nextTemplate: _useGlobalNext ? null : _nextTpl,
              arrivalTemplate: _useGlobalArrival ? null : _arrTpl,
            );
            Navigator.pop(context, {
              'action': 'save',
              'station': s,
              'order': int.tryParse(_orderCtrl.text) ?? 1,
            });
          },
          child: const Text("確定"),
        ),
      ],
    );
  }
}

class EditStationNameDialog extends StatefulWidget {
  final BusStation station;

  const EditStationNameDialog({super.key, required this.station});

  @override
  State<EditStationNameDialog> createState() => _EditStationNameDialogState();
}

class _EditStationNameDialogState extends State<EditStationNameDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _nameEnCtrl;
  late List<String> _nextTpl;
  late List<String> _arrTpl;
  late bool _useGlobalNext;
  late bool _useGlobalArrival;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.station.name);
    _nameEnCtrl = TextEditingController(text: widget.station.nameEn);
    _nextTpl = List.from(widget.station.nextTemplate ?? ["下一站", "{name}"]);
    _arrTpl = List.from(widget.station.arrivalTemplate ?? ["{name}", "到了"]);
    _useGlobalNext = widget.station.useGlobalNext;
    _useGlobalArrival = widget.station.useGlobalArrival;
  }

  Future<String?> _showTextDialog(String initial) async {
    final c = TextEditingController(text: initial);
    return await showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        title: const Text("編輯片段"),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("編輯站點", style: TextStyle(fontSize: 14)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "站名"),
              ),
              TextField(
                controller: _nameEnCtrl,
                decoration: const InputDecoration(labelText: "英文站名"),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text("下一站同步全域", style: TextStyle(fontSize: 12)),
                value: _useGlobalNext,
                onChanged: (v) => setState(() => _useGlobalNext = v),
                dense: true,
              ),
              if (!_useGlobalNext)
                SequenceManagerWidget<String>(
                  title: "自訂下一站序列",
                  items: _nextTpl,
                  onAdd: () => "下一站",
                  onEdit: (val) => _showTextDialog(val),
                ),
              SwitchListTile(
                title: const Text("到站同步全域", style: TextStyle(fontSize: 12)),
                value: _useGlobalArrival,
                onChanged: (v) => setState(() => _useGlobalArrival = v),
                dense: true,
              ),
              if (!_useGlobalArrival)
                SequenceManagerWidget<String>(
                  title: "自訂到站序列",
                  items: _arrTpl,
                  onAdd: () => "到了",
                  onEdit: (val) => _showTextDialog(val),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("取消"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'name': _nameCtrl.text,
            'nameEn': _nameEnCtrl.text,
            'useGlobalNext': _useGlobalNext,
            'useGlobalArrival': _useGlobalArrival,
            'nextTemplate': _nextTpl,
            'arrivalTemplate': _arrTpl,
          }),
          child: const Text("儲存"),
        ),
      ],
    );
  }
}
