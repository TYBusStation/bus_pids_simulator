import 'package:bus_pids_simulator/utils/formatter_utils.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/bus_station.dart';
import '../../data/led_sequence.dart';

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
                    icon: const Icon(Icons.arrow_upward, size: 14),
                    onPressed: e.key == 0
                        ? null
                        : () => setState(() {
                            final item = widget.items.removeAt(e.key);
                            widget.items.insert(e.key - 1, item);
                          }),
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
  final List<String> routeNames;

  const StationDialog({
    super.key,
    required this.point,
    this.existing,
    required this.currentList,
    this.routeNames = const [],
  });

  @override
  State<StationDialog> createState() => _StationDialogState();
}

class _StationDialogState extends State<StationDialog> {
  late TextEditingController _nameCtrl, _nameEnCtrl, _orderCtrl;
  late List<String> _nextTpl, _arrTpl;
  late List<LedSequence> _nextLedTpl, _arrLedTpl;
  bool _useGlobalNext = true, _useGlobalArrival = true;
  bool _useGlobalNextLed = true, _useGlobalArrivalLed = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? "");
    _nameEnCtrl = TextEditingController(text: widget.existing?.nameEn ?? "");
    bool isExistInRoute =
        widget.existing != null && widget.currentList.contains(widget.existing);
    int initialOrder = isExistInRoute
        ? widget.existing!.order
        : (widget.currentList.length + 1);
    _orderCtrl = TextEditingController(text: initialOrder.toString());

    _nextTpl = List.from(widget.existing?.nextTemplate ?? ["下一站", "{name}"]);
    _arrTpl = List.from(widget.existing?.arrivalTemplate ?? ["{name}", "到了"]);
    _useGlobalNext = widget.existing?.useGlobalNext ?? true;
    _useGlobalArrival = widget.existing?.useGlobalArrival ?? true;

    _useGlobalNextLed = widget.existing?.useGlobalNextLed ?? true;
    _useGlobalArrivalLed = widget.existing?.useGlobalArrivalLed ?? true;
    _nextLedTpl = List.from(
      widget.existing?.nextLedTemplate ?? [LedSequence(template: "下一站 {name}")],
    );
    _arrLedTpl = List.from(
      widget.existing?.arrivalLedTemplate ??
          [LedSequence(template: "{name} 到了")],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  InputDecoration _compactInp(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    labelStyle: const TextStyle(fontSize: 11),
  );

  @override
  Widget build(BuildContext context) {
    bool isExistInRoute =
        widget.existing != null && widget.currentList.contains(widget.existing);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 600,
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
                      decoration: _compactInp("順序"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: _compactInp("站名"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _nameEnCtrl,
                      decoration: _compactInp("英文站名"),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        "語音下站同步全域",
                        style: TextStyle(fontSize: 10),
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
                        "語音到站同步全域",
                        style: TextStyle(fontSize: 10),
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
                              title: "自訂下一站語音",
                              items: _nextTpl,
                              onAdd: () => "下一站",
                              onEdit: (val) =>
                                  FormatterUtils.showTextEditDialog(
                                    context: context,
                                    initialValue: val,
                                  ),
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: !_useGlobalArrival
                          ? SequenceManagerWidget<String>(
                              title: "自訂到站語音",
                              items: _arrTpl,
                              onAdd: () => "到了",
                              onEdit: (val) =>
                                  FormatterUtils.showTextEditDialog(
                                    context: context,
                                    initialValue: val,
                                  ),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        "字幕下站同步全域",
                        style: TextStyle(fontSize: 10),
                      ),
                      value: _useGlobalNextLed,
                      onChanged: (v) => setState(() => _useGlobalNextLed = v),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        "字幕到站同步全域",
                        style: TextStyle(fontSize: 10),
                      ),
                      value: _useGlobalArrivalLed,
                      onChanged: (v) =>
                          setState(() => _useGlobalArrivalLed = v),
                    ),
                  ),
                ],
              ),
              if (!_useGlobalNextLed || !_useGlobalArrivalLed)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: !_useGlobalNextLed
                          ? SequenceManagerWidget<LedSequence>(
                              title: "自訂下一站字幕",
                              items: _nextLedTpl,
                              onAdd: () => LedSequence(template: "下一站"),
                              onEdit: (val) => FormatterUtils.showLedEditDialog(
                                context: context,
                                item: val,
                              ),
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: !_useGlobalArrivalLed
                          ? SequenceManagerWidget<LedSequence>(
                              title: "自訂到站字幕",
                              items: _arrLedTpl,
                              onAdd: () => LedSequence(template: "到了"),
                              onEdit: (val) => FormatterUtils.showLedEditDialog(
                                context: context,
                                item: val,
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (isExistInRoute) ...[
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
              order: int.tryParse(_orderCtrl.text) ?? 1,
              name: _nameCtrl.text,
              nameEn: _nameEnCtrl.text,
              lat: widget.point.latitude,
              lon: widget.point.longitude,
              useGlobalNext: _useGlobalNext,
              useGlobalArrival: _useGlobalArrival,
              nextTemplate: _useGlobalNext ? null : _nextTpl,
              arrivalTemplate: _useGlobalArrival ? null : _arrTpl,
              useGlobalNextLed: _useGlobalNextLed,
              useGlobalArrivalLed: _useGlobalArrivalLed,
              nextLedTemplate: _useGlobalNextLed ? null : _nextLedTpl,
              arrivalLedTemplate: _useGlobalArrivalLed ? null : _arrLedTpl,
            );
            Navigator.pop(context, {
              'action': 'save',
              'station': s,
              'order': s.order,
            });
          },
          child: Text(
            isExistInRoute ? "確定" : "新增",
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
