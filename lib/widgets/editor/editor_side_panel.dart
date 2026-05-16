import 'package:flutter/material.dart';

import '../../data/bus_station.dart';

class EditorSidePanel extends StatelessWidget {
  final TextEditingController idCtrl,
      nameCtrl,
      descCtrl,
      depCtrl,
      destCtrl,
      wktCtrl;
  final bool isEditingGo, autoWkt;
  final List<BusStation> stations;
  final Function(bool) onDirectionChanged;
  final Function(bool) onAutoWktChanged;
  final VoidCallback onWktManualChanged;
  final Function(int, int) onReorder;
  final Function(int) onStationRemove;

  const EditorSidePanel({
    super.key,
    required this.idCtrl,
    required this.nameCtrl,
    required this.descCtrl,
    required this.depCtrl,
    required this.destCtrl,
    required this.wktCtrl,
    required this.isEditingGo,
    required this.autoWkt,
    required this.stations,
    required this.onDirectionChanged,
    required this.onAutoWktChanged,
    required this.onWktManualChanged,
    required this.onReorder,
    required this.onStationRemove,
  });

  InputDecoration _denseInp(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    labelStyle: const TextStyle(fontSize: 10),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: idCtrl,
                        style: const TextStyle(fontSize: 11),
                        decoration: _denseInp("ID"),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        style: const TextStyle(fontSize: 11),
                        decoration: _denseInp("名稱"),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(fontSize: 10),
                  decoration: _denseInp("描述"),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: depCtrl,
                        style: const TextStyle(fontSize: 10),
                        decoration: _denseInp("起點"),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: destCtrl,
                        style: const TextStyle(fontSize: 10),
                        decoration: _denseInp("終點"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(children: [_dirBtn(true, "去程"), _dirBtn(false, "回程")]),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: wktCtrl,
                        enabled: !autoWkt,
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(4),
                        ),
                        onChanged: (_) => onWktManualChanged(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text("自動", style: TextStyle(fontSize: 8)),
                    SizedBox(
                      height: 18,
                      width: 28,
                      child: Transform.scale(
                        scale: 0.5,
                        child: Switch(
                          value: autoWkt,
                          onChanged: onAutoWktChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: stations.length,
              onReorder: onReorder,
              itemBuilder: (ctx, i) => _compactStationTile(i, stations[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dirBtn(bool isGo, String label) => Expanded(
    child: SizedBox(
      height: 26,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEditingGo == isGo
              ? Colors.orange
              : Colors.grey[850],
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => onDirectionChanged(isGo),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );

  Widget _compactStationTile(int i, BusStation s) => Padding(
    key: ValueKey("${isEditingGo ? 'g' : 'b'}$i"),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        ReorderableDragStartListener(
          index: i,
          child: const Icon(Icons.drag_indicator, size: 14, color: Colors.grey),
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 8,
          backgroundColor: Colors.orange,
          child: Text(
            "${i + 1}",
            style: const TextStyle(fontSize: 7, color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            s.name,
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, size: 12),
          onPressed: () => onStationRemove(i),
        ),
      ],
    ),
  );
}
