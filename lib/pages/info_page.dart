import 'package:bus_pids_simulator/utils/web_interop.dart'
    if (dart.library.js_interop) 'package:bus_pids_simulator/utils/web_interop_web.dart'
    if (dart.library.html) 'package:bus_pids_simulator/utils/web_interop_web.dart'
    if (dart.library.io) 'package:bus_pids_simulator/utils/web_interop_stub.dart';
import 'package:bus_pids_simulator/widgets/status_panal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _volController;
  late TextEditingController _speedController;
  late AnimationController _flashController;
  bool _isWakeLocked = false;

  @override
  void initState() {
    super.initState();
    _volController = TextEditingController(
      text: Static.globalVolume.toStringAsFixed(2),
    );
    _speedController = TextEditingController(
      text: Static.globalSpeed.toStringAsFixed(2),
    );
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _volController.dispose();
    _speedController.dispose();
    _flashController.dispose();
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

  void _toggleFullscreen() {
    FocusScope.of(context).unfocus();
    getWebInterop().toggleFullscreen();
  }

  void _toggleWakeLock() {
    setState(() {
      _isWakeLocked = !_isWakeLocked;
      WakelockPlus.toggle(enable: _isWakeLocked);
    });
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
        final analysis = analysisProvider.currentAnalysis;

        String nextStationName = "(無停靠站)";
        String nextStationNameEn = "";
        String distanceText = "";

        if (currentStatus.dutyStatus == DutyStatus.offDuty) {
          nextStationName = "(非營運)";
        } else if (locNotifier.currentLocation == null) {
          nextStationName = "(無定位)";
        } else if (analysis != null) {
          if (analysis.prevStation != null &&
              (analysis.distToPrevStation ?? double.infinity) <
                  Static.nextStationDepartureDistance) {
            nextStationName = analysis.prevStation!.name;
            nextStationNameEn = analysis.prevStation!.nameEn;
            distanceText =
                "0 m(離站 ${analysis.distToPrevStation!.toStringAsFixed(0)} m)";
          } else if (analysis.nextStation != null) {
            nextStationName = analysis.nextStation!.name;
            nextStationNameEn = analysis.nextStation!.nameEn;
            String baseDist = analysis.distToNextStation != null
                ? "${analysis.distToNextStation!.toStringAsFixed(0)} m"
                : "";
            distanceText = analysis.isOffRoute ? "$baseDist (脫離路線)" : baseDist;
          }
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
                child: StatusPanel(
                  currentStatus: currentStatus,
                  nextStationName: nextStationName,
                  nextStationNameEn: nextStationNameEn,
                  distanceText: distanceText,
                  isOnDuty: currentStatus.dutyStatus == DutyStatus.onDuty,
                  isOffDutyAlert: analysisProvider.isOffDutyAlert,
                  flashController: _flashController,
                  statusNotifier: statusNotifier,
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
      width: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white, width: 2),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Icon(
                    hasLocation ? Icons.location_on : Icons.location_off,
                    color: hasLocation ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  Text(
                    hasLocation ? "定位正常" : "無定位",
                    style: TextStyle(
                      color: hasLocation ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    _buildInfoRow(
                      "時速",
                      "${loc.currentSpeed.toStringAsFixed(1)}",
                      Colors.orangeAccent,
                    ),
                    _buildInfoRow(
                      "緯度",
                      hasLocation
                          ? loc.currentLocation!.latitude.toStringAsFixed(4)
                          : "N/A",
                      Colors.white,
                    ),
                    _buildInfoRow(
                      "經度",
                      hasLocation
                          ? loc.currentLocation!.longitude.toStringAsFixed(4)
                          : "N/A",
                      Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Static.TTS.speak(" ");
                loc.forceRefresh();
              },
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
              ),
              child: const Text("重新定位", style: TextStyle(fontSize: 10)),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggleWakeLock,
                  icon: Icon(
                    _isWakeLocked ? Icons.lightbulb : Icons.lightbulb_outline,
                    size: 12,
                  ),
                  label: Text(
                    _isWakeLocked ? "螢幕恆亮" : "螢幕非恆亮",
                    style: const TextStyle(fontSize: 9),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isWakeLocked
                        ? Colors.orange
                        : theme.colorScheme.secondary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen, size: 12),
                  label: const Text("全螢幕", style: TextStyle(fontSize: 9)),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                  ),
                ),
              ),
            ],
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
          const SizedBox(height: 4),
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

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
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
        Icon(icon, size: 16),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: (v) {
                Static.TTS.speak(" ");
                onSlider(v);
              },
            ),
          ),
        ),
        SizedBox(
          width: 35,
          height: 24,
          child: TextField(
            controller: ctrl,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
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
}
