import 'package:bus_pids_simulator/pages/route_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

import '../data/status.dart';
import '../utils/static.dart';
import '../widgets/location_provider.dart';
import '../widgets/route_analysis_provider.dart';
import '../widgets/status_provider.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  late TextEditingController _volController;
  late TextEditingController _speedController;

  @override
  void initState() {
    super.initState();
    _volController = TextEditingController(
      text: Static.globalVolume.toStringAsFixed(2),
    );
    _speedController = TextEditingController(
      text: Static.globalSpeed.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _volController.dispose();
    _speedController.dispose();
    super.dispose();
  }

  void _updateVolume(double v) {
    setState(() {
      Static.globalVolume = v.clamp(0.0, 1.0);
      _volController.text = Static.globalVolume.toStringAsFixed(2);
    });
  }

  void _updateSpeed(double v) {
    setState(() {
      Static.globalSpeed = v.clamp(0.5, 2.0);
      _speedController.text = Static.globalSpeed.toStringAsFixed(2);
    });
  }

  Future<void> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("確定"),
          ),
        ],
      ),
    );
    if (result == true) onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer3<
      LocationChangeNotifier,
      StatusChangeNotifier,
      RouteAnalysisProvider
    >(
      builder: (context, locNotifier, statusNotifier, analysisProvider, child) {
        final currentStatus = statusNotifier.currentStatus;
        final bool isOnDuty = currentStatus.dutyStatus == DutyStatus.onDuty;
        final analysis = analysisProvider.currentAnalysis;

        String nextStationName = "(無停靠站)";
        String distanceText = "";

        if (currentStatus.dutyStatus == DutyStatus.offDuty) {
          nextStationName = "(非營運)";
        } else if (locNotifier.currentLocation == null) {
          nextStationName = "(無定位)";
        } else if (analysis != null && analysis.nextStation != null) {
          nextStationName = analysis.nextStation!.name;
          String baseDist = analysis.distToNextStation != null
              ? "${analysis.distToNextStation!.toStringAsFixed(0)}m"
              : "";
          distanceText = analysis.isOffRoute ? "$baseDist (脫離路線)" : baseDist;
        }

        return Container(
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLeftStatusPanel(locNotifier, theme),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRightActionPanel(
                  context,
                  statusNotifier,
                  nextStationName,
                  distanceText,
                  isOnDuty,
                  theme,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeftStatusPanel(LocationChangeNotifier loc, ThemeData theme) {
    bool hasLocation = loc.currentLocation != null;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white, width: 2),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Column(
        children: [
          Icon(
            hasLocation ? Icons.location_on : Icons.location_off,
            color: hasLocation ? Colors.green : Colors.red,
            size: 36,
          ),
          Text(
            hasLocation ? "定位正常" : "等待定位",
            style: TextStyle(
              color: hasLocation ? Colors.green : Colors.red,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: () => loc.forceRefresh(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 30),
            ),
            child: const Text("手動重定位", style: TextStyle(fontSize: 11)),
          ),
          const Spacer(),
          _buildControlRow(
            Icons.volume_up,
            Static.globalVolume,
            0.0,
            1.0,
            _updateVolume,
            _volController,
          ),
          const SizedBox(height: 8),
          _buildControlRow(
            Icons.speed,
            Static.globalSpeed,
            0.5,
            2.0,
            _updateSpeed,
            _speedController,
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow(
    IconData icon,
    double value,
    double min,
    double max,
    Function(double) onSlider,
    TextEditingController ctrl,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18),
        Expanded(
          flex: 4,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onSlider,
            ),
          ),
        ),
        const Spacer(flex: 1),
        SizedBox(
          width: 48,
          height: 28,
          child: TextField(
            controller: ctrl,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (s) {
              final val = double.tryParse(s);
              if (val != null) onSlider(val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRightActionPanel(
    BuildContext context,
    StatusChangeNotifier notifier,
    String nextStation,
    String distance,
    bool isOnDuty,
    ThemeData theme,
  ) {
    final status = notifier.currentStatus;
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: _buildDashboardBox(
            theme: theme,
            color: Colors.grey.shade700,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      "下一站",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      distance,
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 55,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        const style = TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          height: 1.1,
                        );
                        final painter = TextPainter(
                          text: TextSpan(text: nextStation, style: style),
                          maxLines: 1,
                          textDirection: TextDirection.ltr,
                        )..layout();
                        return painter.width > box.maxWidth
                            ? Marquee(
                                text: nextStation,
                                style: style,
                                blankSpace: 80,
                                velocity: 40,
                                pauseAfterRound: const Duration(seconds: 2),
                                accelerationDuration: const Duration(
                                  seconds: 1,
                                ),
                              )
                            : Center(child: Text(nextStation, style: style));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () async {
                    final newStatus = await Navigator.push<Status>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RouteSelectionPage(),
                      ),
                    );
                    if (newStatus != null) notifier.setStatus(newStatus);
                  },
                  child: _buildDashboardBox(
                    theme: theme,
                    color: Colors.grey.shade700,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          child: Text(
                            "路線：${status.route.name}(${status.route.id})",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            height: 22,
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final description = status.route.description;
                                final directionSuffix =
                                    " | ${status.direction == Direction.go ? '去程' : '返程'} 往 ${status.direction == Direction.go ? status.route.destination : status.route.departure}";
                                const style = TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                );

                                final descPainter = TextPainter(
                                  text: TextSpan(
                                    text: description,
                                    style: style,
                                  ),
                                  maxLines: 1,
                                  textDirection: TextDirection.ltr,
                                )..layout();

                                final suffixPainter = TextPainter(
                                  text: TextSpan(
                                    text: directionSuffix,
                                    style: style,
                                  ),
                                  maxLines: 1,
                                  textDirection: TextDirection.ltr,
                                )..layout();

                                if (descPainter.width + suffixPainter.width >
                                    box.maxWidth) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Marquee(
                                          text: description,
                                          style: style,
                                          blankSpace: 40,
                                          velocity: 30,
                                          pauseAfterRound: const Duration(
                                            seconds: 2,
                                          ),
                                        ),
                                      ),
                                      Text(directionSuffix, style: style),
                                    ],
                                  );
                                } else {
                                  return Center(
                                    child: Text(
                                      "$description$directionSuffix",
                                      style: style,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () => _showConfirmDialog(
                    context: context,
                    title:
                        "切換${status.direction == Direction.go ? '返程' : '去程'}",
                    content:
                        "是否確定切換${status.direction == Direction.go ? '返程' : '去程'}？",
                    onConfirm: () => notifier.setStatus(
                      Status(
                        route: status.route,
                        direction: status.direction == Direction.go
                            ? Direction.back
                            : Direction.go,
                        dutyStatus: DutyStatus.offDuty,
                      ),
                    ),
                  ),
                  child: _buildDashboardBox(
                    theme: theme,
                    color: Colors.blue.shade600,
                    child: const Center(
                      child: FittedBox(
                        child: Text(
                          "切換去返程",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => _showConfirmDialog(
              context: context,
              title: isOnDuty ? '結束營運' : '開始營運',
              content: "是否確定${isOnDuty ? '結束營運' : '開始營運'}？",
              onConfirm: () => notifier.setStatus(
                Status(
                  route: status.route,
                  direction: status.direction,
                  dutyStatus: isOnDuty ? DutyStatus.offDuty : DutyStatus.onDuty,
                ),
              ),
            ),
            child: _buildDashboardBox(
              theme: theme,
              color: isOnDuty ? Colors.green.shade600 : Colors.red.shade600,
              child: Center(
                child: FittedBox(
                  child: Text(
                    '車輛狀態：${isOnDuty ? "營運中 【點我結束營運】" : "非營運 【點我開始營運】"}',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardBox({
    required Widget child,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: child,
    );
  }
}
