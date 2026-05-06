import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

import '../data/status.dart';
import '../pages/route_selection_page.dart';
import '../utils/static.dart';
import 'status_provider.dart';

class StatusPanel extends StatelessWidget {
  final Status currentStatus;
  final String nextStationName;
  final String nextStationNameEn;
  final String distanceText;
  final bool isOnDuty;
  final bool isOffDutyAlert;
  final AnimationController flashController;
  final StatusChangeNotifier statusNotifier;

  const StatusPanel({
    super.key,
    required this.currentStatus,
    required this.nextStationName,
    required this.nextStationNameEn,
    required this.distanceText,
    required this.isOnDuty,
    required this.isOffDutyAlert,
    required this.flashController,
    required this.statusNotifier,
  });

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
            onPressed: () {
              Static.TTS.speak(" ");
              Navigator.pop(context, false);
            },
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Static.TTS.speak(" ");
              Navigator.pop(context, true);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
    if (result == true) onConfirm();
  }

  Widget _buildDashboardBox({required Widget child, required Color color}) {
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

  Widget _buildAutoScrollingText({
    required String text,
    required TextStyle style,
  }) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: cleanText, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final bool isOverflowing = painter.width > constraints.maxWidth;

        if (isOverflowing) {
          return Marquee(
            text: cleanText,
            style: style,
            blankSpace: 80.0,
            velocity: 40.0,
            startPadding: 10.0,
            pauseAfterRound: const Duration(seconds: 2),
            accelerationDuration: const Duration(seconds: 1),
          );
        } else {
          return Center(
            child: FittedBox(
              child: Text(
                cleanText,
                style: style,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: _buildDashboardBox(
            color: Colors.grey,
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
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      distanceText,
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 40,
                    child: _buildAutoScrollingText(
                      text: nextStationName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 28,
                    child: _buildAutoScrollingText(
                      text: nextStationNameEn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.0,
                      ),
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
                    Static.TTS.speak(" ");
                    final newStatus = await Navigator.push<Status>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RouteSelectionPage(),
                      ),
                    );
                    if (newStatus != null) statusNotifier.setStatus(newStatus);
                  },
                  child: _buildDashboardBox(
                    color: Colors.grey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          child: Text(
                            "路線：${currentStatus.route.name}(${currentStatus.route.id})",
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
                                final description =
                                    currentStatus.route.description;
                                final directionSuffix =
                                    " | ${currentStatus.direction == Direction.go ? '去程' : '返程'} 往 ${currentStatus.direction == Direction.go ? currentStatus.route.destination : currentStatus.route.departure}";
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
                  onTap: () {
                    Static.TTS.speak(" ");
                    _showConfirmDialog(
                      context: context,
                      title:
                          "切換${currentStatus.direction == Direction.go ? '返程' : '去程'}",
                      content:
                          "是否確定切換${currentStatus.direction == Direction.go ? '返程' : '去程'}？",
                      onConfirm: () => statusNotifier.setStatus(
                        Status(
                          route: currentStatus.route,
                          direction: currentStatus.direction == Direction.go
                              ? Direction.back
                              : Direction.go,
                          dutyStatus: DutyStatus.offDuty,
                        ),
                      ),
                    );
                  },
                  child: _buildDashboardBox(
                    color: Colors.blue,
                    child: Center(
                      child: FittedBox(
                        child: Text(
                          "切換${currentStatus.direction == Direction.go ? '返程' : '去程'}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
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
            onTap: () {
              Static.TTS.speak(" ");
              _showConfirmDialog(
                context: context,
                title: isOnDuty ? '結束營運' : '開始營運',
                content: "是否確定${isOnDuty ? '結束營運' : '開始營運'}？",
                onConfirm: () {
                  statusNotifier.setStatus(
                    Status(
                      route: currentStatus.route,
                      direction: currentStatus.direction,
                      dutyStatus: isOnDuty
                          ? DutyStatus.offDuty
                          : DutyStatus.onDuty,
                    ),
                  );
                },
              );
            },
            child: AnimatedBuilder(
              animation: flashController,
              builder: (context, child) {
                Color boxColor = isOnDuty
                    ? Colors.green
                    : (isOffDutyAlert
                          ? (flashController.value > 0.5
                                ? Colors.red
                                : Colors.grey)
                          : Colors.red);
                return _buildDashboardBox(
                  color: boxColor,
                  child: Center(
                    child: FittedBox(
                      child: Text(
                        '車輛狀態：${isOnDuty ? "營運中 【點我結束營運】" : "非營運 【點我開始營運】"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
