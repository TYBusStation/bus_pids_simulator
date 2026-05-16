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

    return Scaffold(
      body: Padding(
        padding: EdgeInsetsGeometry.only(bottom: 40),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    SegmentedButton<GpsMode>(
                      segments: const [
                        ButtonSegment(
                          value: GpsMode.auto,
                          label: Text("自動"),
                          icon: Icon(Icons.gps_fixed),
                        ),
                        ButtonSegment(
                          value: GpsMode.manual,
                          label: Text("模擬"),
                          icon: Icon(Icons.tune),
                        ),
                        ButtonSegment(
                          value: GpsMode.none,
                          label: Text("關閉"),
                          icon: Icon(Icons.gps_off),
                        ),
                      ],
                      selected: {locNotifier.gpsMode},
                      onSelectionChanged: (set) =>
                          locNotifier.setGpsMode(set.first),
                    ),
                    const SizedBox(height: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
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
              ),
              subtitle: Text(
                sim.simRoute == null
                    ? "點擊選擇模擬路線"
                    : "模擬方向：${sim.simDirection == Direction.go ? '去程' : '返程'} | 往 ${sim.simDirection == Direction.go ? sim.simRoute!.destination : sim.simRoute!.departure}",
              ),
            ),
            const Divider(),
            Row(
              children: [
                IconButton.filled(
                  onPressed: sim.simRoute == null
                      ? null
                      : () => sim.toggleSimulation(loc),
                  icon: Icon(sim.isSimulating ? Icons.pause : Icons.play_arrow),
                ),
                Expanded(
                  child: Slider(
                    value: sim.simSpeedKmh,
                    min: 0,
                    max: 120,
                    onChanged: (v) => sim.setSimSpeed(v),
                  ),
                ),
                Text("${sim.simSpeedKmh.toInt()} km/h"),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => sim.setSimRoute(
                  status.currentStatus.route,
                  status.currentStatus.direction,
                ),
                icon: const Icon(Icons.check),
                label: const Text("設為當前執行路線"),
              ),
            ),
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
      shrinkWrap: true,
      itemCount: stations.length,
      itemBuilder: (context, i) => ListTile(
        dense: true,
        leading: Text("${i + 1}"),
        title: Text(stations[i].name),
        trailing: IconButton(
          icon: const Icon(Icons.gps_fixed, size: 14),
          onPressed: () => sim.jumpToStation(i, loc),
        ),
      ),
    );
  }
}
