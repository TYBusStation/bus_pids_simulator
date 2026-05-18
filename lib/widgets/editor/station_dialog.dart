import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/bus_station.dart';

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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? "");
    _nameEnCtrl = TextEditingController(
      text: widget.existing?.nameEn ?? "",
    ); // 初始化英文
    _orderCtrl = TextEditingController(
      text: (widget.currentList.length + 1).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isExist = widget.currentList.any(
      (s) => s.lat == widget.point.latitude && s.lon == widget.point.longitude,
    );

    return AlertDialog(
      title: const Text("站點", style: TextStyle(fontSize: 14)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: "站名"), // 還原標籤
          ),
          TextField(
            controller: _nameEnCtrl,
            decoration: const InputDecoration(labelText: "英文站名"),
          ),
          TextField(
            controller: _orderCtrl,
            decoration: const InputDecoration(labelText: "順序"),
            keyboardType: TextInputType.number,
          ),
        ],
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
            );
            Navigator.pop(context, {
              'action': 'save',
              'station': s,
              'order': int.tryParse(_orderCtrl.text) ?? 1,
            });
          },
          child: const Text("加入"),
        ),
      ],
    );
  }
}

class EditStationNameDialog extends StatefulWidget {
  final String name;
  final String nameEn;

  const EditStationNameDialog({
    super.key,
    required this.name,
    required this.nameEn,
  });

  @override
  State<EditStationNameDialog> createState() => _EditStationNameDialogState();
}

class _EditStationNameDialogState extends State<EditStationNameDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _nameEnCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _nameEnCtrl = TextEditingController(text: widget.nameEn);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("編輯站名", style: TextStyle(fontSize: 14)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: "中文站名"),
          ),
          TextField(
            controller: _nameEnCtrl,
            decoration: const InputDecoration(labelText: "英文站名"),
          ),
        ],
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
          }),
          child: const Text("儲存"),
        ),
      ],
    );
  }
}
