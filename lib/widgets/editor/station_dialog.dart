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
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        dense: true,
        visualDensity: const VisualDensity(vertical: -4),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        children: [
          ...widget.items.asMap().entries.map(
            (e) => ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
              contentPadding: const EdgeInsets.only(left: 8, right: 0),
              title: Text(
                e.value is String
                    ? e.value as String
                    : (e.value as dynamic).template,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit, size: 14),
                    onPressed: () async {
                      final result = await widget.onEdit(e.value);
                      if (result != null)
                        setState(() => widget.items[e.key] = result);
                    },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                    onPressed: () =>
                        setState(() => widget.items.removeAt(e.key)),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -4),
            contentPadding: const EdgeInsets.only(left: 8),
            leading: const Icon(Icons.add, size: 14),
            title: const Text("新增", style: TextStyle(fontSize: 11)),
            onTap: () => setState(() => widget.items.add(widget.onAdd())),
          ),
        ],
      ),
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
  late TextEditingController _nameCtrl, _nameEnCtrl, _orderCtrl;
  late List<String> _nextTpl, _arrTpl;
  bool _useGlobalNext = true, _useGlobalArrival = true;

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<String?> _showTextDialog(String initial) async {
    final c = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "編輯片段",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: c,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
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
    c.dispose();
    return result;
  }

  InputDecoration _compactInp(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    labelStyle: const TextStyle(fontSize: 11),
  );

  @override
  Widget build(BuildContext context) {
    bool isExist = widget.currentList.any(
      (s) => s.lat == widget.point.latitude && s.lon == widget.point.longitude,
    );

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "站點設定",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _orderCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: _compactInp("順序"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: _compactInp("站名"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _nameEnCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: _compactInp("英文站名"),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        "下一站報站同步全域",
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _useGlobalNext,
                      onChanged: (v) => setState(() => _useGlobalNext = v),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        "到站報站同步全域",
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _useGlobalArrival,
                      onChanged: (v) => setState(() => _useGlobalArrival = v),
                    ),
                  ),
                ],
              ),
              if (!_useGlobalNext || !_useGlobalArrival)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: !_useGlobalNext
                          ? SequenceManagerWidget<String>(
                              title: "自訂下一站報站",
                              items: _nextTpl,
                              onAdd: () => "下一站",
                              onEdit: (val) => _showTextDialog(val),
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: !_useGlobalArrival
                          ? SequenceManagerWidget<String>(
                              title: "自訂到站報站",
                              items: _arrTpl,
                              onAdd: () => "到了",
                              onEdit: (val) => _showTextDialog(val),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      actions: [
        if (isExist) ...[
          TextButton(
            onPressed: () => Navigator.pop(context, {'action': 'delete'}),
            child: const Text(
              "移除",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {'action': 'move'}),
            child: const Text("移動", style: TextStyle(fontSize: 12)),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context, {'action': 'cancel_move'}),
          child: const Text("取消", style: TextStyle(fontSize: 12)),
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
          child: const Text("確定", style: TextStyle(fontSize: 12)),
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
  late TextEditingController _nameCtrl, _nameEnCtrl;
  late List<String> _nextTpl, _arrTpl;
  late bool _useGlobalNext, _useGlobalArrival;

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    super.dispose();
  }

  Future<String?> _showTextDialog(String initial) async {
    final c = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (v) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "編輯片段",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: c,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
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
    c.dispose();
    return result;
  }

  InputDecoration _compactInp(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    labelStyle: const TextStyle(fontSize: 11),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "編輯站點",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: _compactInp("站名"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _nameEnCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: _compactInp("英文站名"),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        "下一站報站同步全域",
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _useGlobalNext,
                      onChanged: (v) => setState(() => _useGlobalNext = v),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        "到站報站同步全域",
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _useGlobalArrival,
                      onChanged: (v) => setState(() => _useGlobalArrival = v),
                    ),
                  ),
                ],
              ),
              if (!_useGlobalNext || !_useGlobalArrival)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: !_useGlobalNext
                          ? SequenceManagerWidget<String>(
                              title: "自訂下一站報站",
                              items: _nextTpl,
                              onAdd: () => "下一站",
                              onEdit: (val) => _showTextDialog(val),
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: !_useGlobalArrival
                          ? SequenceManagerWidget<String>(
                              title: "自訂到站報站",
                              items: _arrTpl,
                              onAdd: () => "到了",
                              onEdit: (val) => _showTextDialog(val),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, {'action': 'cancel_move'}),
          child: const Text("取消", style: TextStyle(fontSize: 12)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {'action': 'move'}),
          child: const Text("移動", style: TextStyle(fontSize: 12)),
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
          child: const Text("儲存", style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
