import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/status.dart';
import '../pages/route_selection_page.dart';
import '../widgets/gps_control_provider.dart';
import '../widgets/location_provider.dart';
import '../widgets/status_provider.dart';

class GpsControlPage extends StatelessWidget {
  const GpsControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locNotifier = context.watch<LocationChangeNotifier>();
    final simProvider = context.watch<GpsControlProvider>();
    final statusNotifier = context.read<StatusChangeNotifier>();

    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<GpsMode>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: GpsMode.auto,
                          label: Text("自動"),
                          icon: Icon(Icons.gps_fixed, size: 18),
                        ),
                        ButtonSegment(
                          value: GpsMode.manual,
                          label: Text("模擬"),
                          icon: Icon(Icons.tune, size: 18),
                        ),
                        ButtonSegment(
                          value: GpsMode.none,
                          label: Text("關閉"),
                          icon: Icon(Icons.gps_off, size: 18),
                        ),
                      ],
                      selected: {locNotifier.gpsMode},
                      onSelectionChanged: (set) =>
                          locNotifier.setGpsMode(set.first),
                    ),
                    const SizedBox(height: 8),
                    if (locNotifier.gpsMode == GpsMode.manual) ...[
                      _buildSimCard(
                        simProvider,
                        locNotifier,
                        statusNotifier,
                        context,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 1,
            child: locNotifier.gpsMode != GpsMode.manual
                ? const SizedBox.shrink()
                : (simProvider.simRoute == null
                      ? const Center(child: Text("未選擇模擬路線"))
                      : _buildStationList(simProvider, locNotifier)),
          ),
        ],
      ),
    );
  }

  Widget _buildSimCard(
    GpsControlProvider sim,
    LocationChangeNotifier loc,
    StatusChangeNotifier status,
    BuildContext context,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              onTap: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RouteSelectionPage()),
                );
                if (res != null) sim.setSimRoute(res.route, res.direction);
              },
              title: Text(
                sim.simRoute == null
                    ? "尚未選擇模擬路線"
                    : "${sim.simRoute!.name} | ${sim.simRoute!.description}",
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                sim.simRoute == null
                    ? "點擊選擇模擬路線"
                    : "模擬方向：${sim.simDirection == Direction.go ? '去程' : '返程'} | 往 ${sim.simDirection == Direction.go ? sim.simRoute!.destination : sim.simRoute!.departure}",
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const Divider(height: 1),
            Row(
              children: [
                IconButton.filled(
                  visualDensity: VisualDensity.compact,
                  onPressed: sim.simRoute == null
                      ? null
                      : () => sim.toggleSimulation(loc),
                  icon: Icon(
                    sim.isSimulating ? Icons.pause : Icons.play_arrow,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: sim.simSpeedKmh,
                    min: 0,
                    max: 120,
                    onChanged: (v) => sim.setSimSpeed(v),
                  ),
                ),
                Text(
                  "${sim.simSpeedKmh.toInt()} km/h",
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => sim.setSimRoute(
                  status.currentStatus.route,
                  status.currentStatus.direction,
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text("設為當前執行路線", style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildStationList(GpsControlProvider sim, LocationChangeNotifier loc) {
    final stations = sim.simDirection == Direction.go
        ? sim.simRoute!.stations.go
        : sim.simRoute!.stations.back;
    return ListView.builder(
      itemCount: stations.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, i) => ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Text("${i + 1}", style: const TextStyle(fontSize: 12)),
        title: Text(stations[i].name, style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.gps_fixed, size: 14),
          onPressed: () => sim.jumpToStation(i, loc),
        ),
      ),
    );
  }
}
