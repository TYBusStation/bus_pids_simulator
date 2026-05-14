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
  late TextEditingController _orderCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? "");
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
            decoration: const InputDecoration(labelText: "站名"),
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
              nameEn: widget.existing?.nameEn ?? "",
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
