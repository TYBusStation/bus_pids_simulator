import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/bus_station.dart';

class EditorSidePanel extends StatelessWidget {
  final TextEditingController idCtrl,
      nameCtrl,
      nameEnCtrl,
      descCtrl,
      descEnCtrl,
      depCtrl,
      depEnCtrl,
      destCtrl,
      destEnCtrl,
      wktCtrl;
  final bool isEditingGo, autoWkt, isPathEditing;
  final List<BusStation> stations;
  final List<LatLng> pathPoints;
  final Function(bool) onDirectionChanged, onAutoWktChanged;
  final VoidCallback onTogglePathEdit, onWktManualChanged;
  final Function(int, int) onReorder;
  final Function(int) onStationRemove;
  final Function(int, BusStation) onStationTap;
  final Function(int) onPathPointTap;

  const EditorSidePanel({
    super.key,
    required this.idCtrl,
    required this.nameCtrl,
    required this.nameEnCtrl,
    required this.descCtrl,
    required this.descEnCtrl,
    required this.depCtrl,
    required this.depEnCtrl,
    required this.destCtrl,
    required this.destEnCtrl,
    required this.wktCtrl,
    required this.isEditingGo,
    required this.autoWkt,
    required this.isPathEditing,
    required this.stations,
    required this.pathPoints,
    required this.onDirectionChanged,
    required this.onAutoWktChanged,
    required this.onWktManualChanged,
    required this.onTogglePathEdit,
    required this.onReorder,
    required this.onStationRemove,
    required this.onStationTap,
    required this.onPathPointTap,
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
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: isPathEditing ? _buildPathList() : _buildStationList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Column(
        children: [
          if (!isPathEditing) ...[
            TextField(
              controller: idCtrl,
              enabled: !isPathEditing,
              style: const TextStyle(fontSize: 11),
              decoration: _denseInp("ID"),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    enabled: !isPathEditing,
                    style: const TextStyle(fontSize: 10),
                    decoration: _denseInp("名稱"),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: nameEnCtrl,
                    enabled: !isPathEditing,
                    style: const TextStyle(fontSize: 10),
                    decoration: _denseInp("名稱英文"),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: descCtrl,
                    enabled: !isPathEditing,
                    style: const TextStyle(fontSize: 10),
                    decoration: _denseInp("描述"),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: descEnCtrl,
                    enabled: !isPathEditing,
                    style: const TextStyle(fontSize: 10),
                    decoration: _denseInp("描述英文"),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: depCtrl,
                    enabled: !isPathEditing,
                    style: const TextStyle(fontSize: 10),
                    decoration: _denseInp("起點"),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: destCtrl,
                    enabled: !isPathEditing,
                    style: const TextStyle(fontSize: 10),
                    decoration: _denseInp("終點"),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: depEnCtrl,
                    enabled: !isPathEditing,
                    style: const TextStyle(fontSize: 10),
                    decoration: _denseInp("起點英文"),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: destEnCtrl,
                    enabled: !isPathEditing,
                    style: const TextStyle(fontSize: 10),
                    decoration: _denseInp("終點英文"),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Text(
                  "路徑節點編輯",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onTogglePathEdit,
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                wktCtrl.text,
                style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(children: [_dirBtn(true, "去程"), _dirBtn(false, "回程")]),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: onTogglePathEdit,
              icon: Icon(
                isPathEditing ? Icons.list : Icons.edit_road,
                size: 14,
              ),
              label: Text(
                isPathEditing ? "返回編輯站點" : "編輯 WKT 線形",
                style: const TextStyle(fontSize: 10),
              ),
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

  Widget _buildStationList() => ReorderableListView.builder(
    buildDefaultDragHandles: false,
    itemCount: stations.length,
    onReorder: onReorder,
    itemBuilder: (ctx, i) => _compactStationTile(i, stations[i]),
  );

  Widget _buildPathList() => ListView.builder(
    itemCount: pathPoints.length,
    itemBuilder: (ctx, i) => ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: CircleAvatar(
        radius: 7,
        child: Text("${i + 1}", style: const TextStyle(fontSize: 7)),
      ),
      title: Text(
        "${pathPoints[i].latitude.toStringAsFixed(6)}, ${pathPoints[i].longitude.toStringAsFixed(6)}",
        style: const TextStyle(
          fontSize: 9,
          fontFamily: 'monospace',
          color: Colors.grey,
        ),
      ),
      onTap: () => onPathPointTap(i),
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
          child: InkWell(
            onTap: () => onStationTap(i, s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (s.nameEn.isNotEmpty)
                  Text(
                    s.nameEn,
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
