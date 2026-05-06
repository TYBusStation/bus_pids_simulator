import 'package:bus_pids_simulator/widgets/status_panal.dart';
import 'package:flutter/material.dart';
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

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _volController;
  late TextEditingController _speedController;
  late AnimationController _flashController;

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

  void _playVolumeNotice() {
    Static.audioManager.playAssetAndWait("notice.mp3");
  }

  void _updateSpeed(double v) {
    setState(() {
      Static.globalSpeed = v.clamp(0.5, 2.0);
      _speedController.text = Static.globalSpeed.toStringAsFixed(2);
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
        final bool isOnDuty = currentStatus.dutyStatus == DutyStatus.onDuty;
        final bool isOffDutyAlert = analysisProvider.isOffDutyAlert;
        final analysis = analysisProvider.currentAnalysis;

        String nextStationName = "(無停靠站)";
        String nextStationNameEn = "";
        String distanceText = "";

        if (currentStatus.dutyStatus == DutyStatus.offDuty) {
          nextStationName = "(非營運)";
        } else if (locNotifier.currentLocation == null) {
          nextStationName = "(無定位)";
        } else if (analysis != null) {
          final double distPrev = analysis.distToPrevStation ?? double.infinity;

          if (analysis.prevStation != null &&
              distPrev < Static.nextStationDepartureDistance) {
            nextStationName = analysis.prevStation!.name;
            nextStationNameEn = analysis.prevStation!.nameEn;
            distanceText = "0 m(離站 ${distPrev.toStringAsFixed(0)} m)";
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
                  isOnDuty: isOnDuty,
                  isOffDutyAlert: isOffDutyAlert,
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
    double currentSpeed = loc.currentSpeed;
    if (currentSpeed < 0) currentSpeed = 0;

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
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            hasLocation ? "定位正常" : "等待定位",
            style: TextStyle(
              color: hasLocation ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _buildInfoRow(
            "時速",
            "${currentSpeed.toStringAsFixed(1)} km/h",
            Colors.orangeAccent,
          ),
          _buildInfoRow(
            "緯度",
            hasLocation
                ? loc.currentLocation!.latitude.toStringAsFixed(6)
                : "N/A",
            Colors.white,
          ),
          _buildInfoRow(
            "經度",
            hasLocation
                ? loc.currentLocation!.longitude.toStringAsFixed(6)
                : "N/A",
            Colors.white,
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: () {
              Static.TTS.speak(" ");
              loc.forceRefresh();
            },
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
            onChangedEnd: (v) => _playVolumeNotice(),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
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
    TextEditingController ctrl, {
    Function(double)? onChangedEnd,
  }) {
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
              onChanged: (v) {
                Static.TTS.speak(" ");
                onSlider(v);
              },
              onChangeEnd: (v) {
                if (onChangedEnd != null) onChangedEnd(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 45,
          height: 28,
          child: TextField(
            controller: ctrl,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (s) {
              Static.TTS.speak(" ");
              final val = double.tryParse(s);
              if (val != null) {
                onSlider(val);
                if (onChangedEnd != null) onChangedEnd(val);
              }
            },
          ),
        ),
      ],
    );
  }
}
