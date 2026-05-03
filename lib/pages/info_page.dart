import 'package:bus_pids_simulator/pages/route_selection_page.dart';
import 'package:bus_pids_simulator/utils/static.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

import '../data/status.dart';
import '../utils/route_engine.dart';
import '../widgets/location_provider.dart';
import '../widgets/status_provider.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  double _volume = 0.5;
  double _brightness = 0.8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer2<LocationChangeNotifier, StatusChangeNotifier>(
      builder: (context, locNotifier, statusNotifier, child) => LayoutBuilder(
        builder: (context, constraints) {
          final currentStatus = statusNotifier.currentStatus;
          final bool isOnDuty = currentStatus.dutyStatus == DutyStatus.onDuty;

          String nextStationName = "(無停靠站)";
          String distanceText = "";

          if (currentStatus.dutyStatus == DutyStatus.offDuty) {
            nextStationName = "(非營運)";
          } else if (locNotifier.currentLocation == null) {
            nextStationName = "(無定位)";
          } else {
            final stations = currentStatus.direction == Direction.go
                ? currentStatus.route.stations.go
                : currentStatus.route.stations.back;
            final path = currentStatus.direction == Direction.go
                ? currentStatus.route.path.goPoints
                : currentStatus.route.path.backPoints;

            if (stations.isNotEmpty && path.isNotEmpty) {
              final result = RouteEngine.analyze(
                currentPos: locNotifier.currentLocation!,
                routePoints: path,
                stations: stations,
              );
              if (result.nextStation != null) {
                nextStationName = result.nextStation!.name;
                String baseDist = result.distToNextStation != null
                    ? "${(result.distToNextStation! / 1000).toStringAsFixed(2)} km"
                    : "";
                distanceText = result.isOffRoute
                    ? "$baseDist (脫離路線)"
                    : baseDist;
              }
            }
          }

          return Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(DateTime.now()),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLeftStatusPanel(locNotifier, theme),
                      const SizedBox(width: 15),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeftStatusPanel(LocationChangeNotifier loc, ThemeData theme) {
    bool hasLocation = loc.currentLocation != null;
    final colorScheme = theme.colorScheme;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white, // 改為白框
          width: 2,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Static.requestLocationPermission(),
            child: Icon(
              hasLocation ? Icons.location_on : Icons.location_off,
              color: hasLocation ? Colors.green : colorScheme.error,
              size: 60,
            ),
          ),
          if (hasLocation) ...[
            Text(
              "緯度：${loc.currentLocation!.latitude.toStringAsFixed(6)}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "經度：${loc.currentLocation!.longitude.toStringAsFixed(6)}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else
            Text(
              "無訊號",
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          const Spacer(),
          _buildSliderWithIcon(
            theme,
            icon: Icons.brightness_6,
            value: _brightness,
            onChanged: (v) => setState(() => _brightness = v),
          ),
          const SizedBox(height: 10),
          _buildSliderWithIcon(
            theme,
            icon: Icons.volume_up,
            value: _volume,
            onChanged: (v) => setState(() => _volume = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderWithIcon(
    ThemeData theme, {
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      // 改為 Row 讓圖示在左側
      children: [
        Icon(
          icon,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          size: 24,
        ),
        Expanded(
          child: SliderTheme(
            data: theme.sliderTheme.copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(value: value, onChanged: onChanged),
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
          flex: 5,
          child: _buildDashboardBox(
            theme: theme,
            color: Colors.grey.shade700, // 灰底
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "下一站",
                  style: TextStyle(
                    color: Colors.white, // 白字
                    fontSize: 20,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      nextStation,
                      style: const TextStyle(
                        color: Colors.white, // 白字
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (distance.isNotEmpty)
                  Text(
                    distance,
                    style: const TextStyle(
                      color: Colors.white, // 白字
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
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
                    color: Colors.grey.shade700, // 灰底
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "路線：${status.route.name}(${status.route.id})",
                            style: const TextStyle(
                              color: Colors.white, // 白字
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    const style = TextStyle(
                                      color: Colors.white, // 白字
                                      fontSize: 18,
                                    );
                                    final painter = TextPainter(
                                      text: TextSpan(
                                        text: status.route.description,
                                        style: style,
                                      ),
                                      maxLines: 1,
                                      textDirection: TextDirection.ltr,
                                    )..layout();
                                    if (painter.width > box.maxWidth) {
                                      return SizedBox(
                                        height: 25,
                                        child: Marquee(
                                          text: status.route.description,
                                          style: style,
                                          blankSpace: 50,
                                          velocity: 30,
                                          pauseAfterRound: const Duration(
                                            seconds: 2,
                                          ),
                                        ),
                                      );
                                    } else {
                                      return Text(
                                        status.route.description,
                                        style: style,
                                      );
                                    }
                                  },
                                ),
                              ),
                              Text(
                                " | 往 ${status.direction == Direction.go ? status.route.destination : status.route.departure}",
                                style: const TextStyle(
                                  color: Colors.white, // 白字
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () {
                    notifier.setStatus(
                      Status(
                        route: status.route,
                        direction: status.direction == Direction.go
                            ? Direction.back
                            : Direction.go,
                        dutyStatus: status.dutyStatus,
                      ),
                    );
                  },
                  child: _buildDashboardBox(
                    theme: theme,
                    color: Colors.blue.shade600,
                    child: Center(
                      child: Text(
                        "切換\n${status.direction == Direction.go ? '返程' : '去程'}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () {
              notifier.setStatus(
                Status(
                  route: status.route,
                  direction: status.direction,
                  dutyStatus: isOnDuty ? DutyStatus.offDuty : DutyStatus.onDuty,
                ),
              );
            },
            child: _buildDashboardBox(
              theme: theme,
              color: isOnDuty ? Colors.green.shade600 : Colors.red.shade600,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "車輛狀態：${isOnDuty ? '營運中' : '非營運'} (點我切換)",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
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
        border: Border.all(
          color: Colors.white, // 全部統一加上白框
          width: 2,
        ),
      ),
      child: child,
    );
  }
}
