import 'package:bus_pids_simulator/pages/route_selection_page.dart';
import 'package:bus_pids_simulator/utils/static.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/status.dart';
import '../utils/route_engine.dart';
import '../widgets/location_provider.dart';
import '../widgets/status_provider.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationChangeNotifier, StatusChangeNotifier>(
      builder: (context, locNotifier, statusNotifier, child) => LayoutBuilder(
        builder: (context, constraints) {
          double leftWidth = 420;
          double spacing = 20;
          double minRightWidth = 350;
          double horizontalPadding = 24;

          double availableWidth = constraints.maxWidth - horizontalPadding;
          bool isSideBySide =
              availableWidth >= (leftWidth + spacing + minRightWidth + 5);

          String nextStationName = "無停靠站";
          String distanceText = "";
          final currentStatus = statusNotifier.currentStatus;

          if (currentStatus.dutyStatus == DutyStatus.offDuty) {
            nextStationName = "非營運";
          } else if (locNotifier.currentLocation == null) {
            nextStationName = "無定位";
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

          Widget leftPart = SizedBox(
            width: leftWidth,
            child: Column(
              children: [
                _buildGpsStatusCard(locNotifier),
                const SizedBox(height: 15),
                _buildNextStationCard(nextStationName, distanceText),
              ],
            ),
          );

          Widget rightPart = Column(
            children: [
              _buildRouteSelectButton(context, statusNotifier),
              const SizedBox(height: 15),
              _buildDutyStatusButton(statusNotifier),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: isSideBySide
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        leftPart,
                        SizedBox(width: spacing),
                        Expanded(child: rightPart),
                      ],
                    )
                  : Column(
                      children: [
                        leftPart,
                        const SizedBox(height: 25),
                        rightPart,
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGpsStatusCard(LocationChangeNotifier loc) {
    bool hasLocation = loc.currentLocation != null;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasLocation ? Colors.green : Colors.red,
          width: 4,
        ),
        borderRadius: BorderRadius.circular(15),
        color: hasLocation
            ? Colors.green.withOpacity(0.08)
            : Colors.red.withOpacity(0.08),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation ? Icons.location_on : Icons.location_off,
            size: 70,
            color: hasLocation ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLocation) ...[
                  Text(
                    "緯度：${loc.currentLocation!.latitude.toStringAsFixed(6)}",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "經度：${loc.currentLocation!.longitude.toStringAsFixed(6)}",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  const Text(
                    "無法讀取定位資料",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextButton(
                    style: TextButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 2),
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () => Static.requestLocationPermission(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 18),
                        SizedBox(width: 5),
                        Text("重新嘗試讀取"),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStationCard(String name, String dist) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 3),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        children: [
          const Text(
            "下一站",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (dist.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "距離：$dist",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteSelectButton(
    BuildContext context,
    StatusChangeNotifier notifier,
  ) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(100),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 5),
        ),
        padding: const EdgeInsets.all(20),
      ),
      onPressed: () async {
        final newStatus = await Navigator.push<Status>(
          context,
          MaterialPageRoute(builder: (context) => const RouteSelectionPage()),
        );
        if (newStatus != null) notifier.setStatus(newStatus);
      },
      child: Text(
        '${notifier.currentStatus.route.name}(${notifier.currentStatus.route.id})\n${notifier.currentStatus.route.description}\n往 ${notifier.currentStatus.direction == Direction.go ? notifier.currentStatus.route.destination : notifier.currentStatus.route.departure}\n[ 點擊切換路線 ]',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, height: 1.3),
      ),
    );
  }

  Widget _buildDutyStatusButton(StatusChangeNotifier notifier) {
    bool isOnDuty = notifier.currentStatus.dutyStatus == DutyStatus.onDuty;
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(100),
        backgroundColor: isOnDuty ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 5),
        ),
        padding: const EdgeInsets.all(20),
      ),
      onPressed: () {
        notifier.setStatus(
          Status(
            route: notifier.currentStatus.route,
            direction: notifier.currentStatus.direction,
            dutyStatus: isOnDuty ? DutyStatus.offDuty : DutyStatus.onDuty,
          ),
        );
      },
      child: Text(
        "${isOnDuty ? '營運中' : '非營運'}\n[ 點擊切換狀態 ]",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      ),
    );
  }
}
