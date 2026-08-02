import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../data/status.dart';
import '../utils/static.dart';
import '../widgets/route_analysis_provider.dart';
import '../widgets/status_provider.dart';

class LottiePage extends StatefulWidget {
  const LottiePage({super.key});

  @override
  State<LottiePage> createState() => _LottiePageState();
}

class _LottiePageState extends State<LottiePage> with TickerProviderStateMixin {
  late final AnimationController _controller;
  DateTime? _lastEventTime;
  bool _isPriorityMode = false;
  LedBroadcastType _activeType = LedBroadcastType.slogan;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _handleAnimationComplete();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouteAnalysisProvider>().addListener(_onLedEventChanged);
    });
  }

  @override
  void dispose() {
    context.read<RouteAnalysisProvider>().removeListener(_onLedEventChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onLedEventChanged() {
    final event = context.read<RouteAnalysisProvider>().currentLedEvent;
    if (event.timestamp != _lastEventTime &&
        event.type != LedBroadcastType.slogan) {
      _lastEventTime = event.timestamp;
      setState(() {
        _isPriorityMode = true;
        _activeType = event.type;
      });
      _controller.forward(from: 0);
    }
  }

  void _handleAnimationComplete() {
    if (!mounted) return;
    if (_isPriorityMode && _activeType == LedBroadcastType.next) {
      setState(() {
        _isPriorityMode = false;
        _activeType = LedBroadcastType.slogan;
      });
    }
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = context.watch<StatusChangeNotifier>();
    final analysisProvider = context.watch<RouteAnalysisProvider>();
    final st = statusProvider.currentStatus;
    final currentEvent = analysisProvider.currentLedEvent;
    final now = DateTime.now();

    String destination = st.direction == Direction.go
        ? st.route.destination
        : st.route.departure;
    final stations = st.direction == Direction.go
        ? st.route.stations.go
        : st.route.stations.back;

    int idx = -1;
    if (analysisProvider.displayStation != null) {
      idx = stations.indexWhere(
        (s) => s.order == analysisProvider.displayStation!.order,
      );
    }

    Map<String, String> textMap = {
      'name': currentEvent.name,
      'nameEn': currentEvent.nameEn,
      'terminal': currentEvent.isTerminal ? "終點站" : "",
      'route_name': st.route.name,
      'route_desc': st.route.description ?? "",
      'route_dest': destination,
      'hh': now.hour.toString().padLeft(2, '0'),
      'mm': now.minute.toString().padLeft(2, '0'),
      'ss': now.second.toString().padLeft(2, '0'),
    };

    for (int i = 1; i <= 15; i++) {
      String pName = "", pEn = "", nName = "", nEn = "";
      if (idx != -1) {
        if (idx - i >= 0) {
          pName = stations[idx - i].name;
          pEn = stations[idx - i].nameEn;
        }
        if (idx + i < stations.length) {
          nName = stations[idx + i].name;
          nEn = stations[idx + i].nameEn;
        }
      }
      textMap['PrevName$i'] = pName;
      textMap['PrevNameEn$i'] = pEn;
      textMap['NextName$i'] = nName;
      textMap['NextNameEn$i'] = nEn;
    }

    final displayType = _isPriorityMode ? _activeType : LedBroadcastType.slogan;
    Uint8List? activeLottie;
    if (displayType == LedBroadcastType.next)
      activeLottie = Static.lottieNext;
    else if (displayType == LedBroadcastType.arrival)
      activeLottie = Static.lottieArrival;
    else
      activeLottie = Static.lottieSlogan;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: activeLottie == null
            ? Text(
                "尚未上傳 ${displayType == LedBroadcastType.next
                    ? '下一站'
                    : displayType == LedBroadcastType.arrival
                    ? '到站'
                    : '行進間'} 檔案",
                style: const TextStyle(color: Colors.white),
              )
            : Lottie.memory(
                activeLottie,
                controller: _controller,
                key: ValueKey("${displayType}_$_lastEventTime"),
                onLoaded: (composition) {
                  _controller.duration = composition.duration;
                  _controller.forward(from: 0);
                },
                delegates: LottieDelegates(
                  text: (initialText) {
                    String result = initialText;
                    textMap.forEach((key, value) {
                      result = result.replaceAll('{$key}', value);
                    });
                    return result;
                  },
                ),
              ),
      ),
    );
  }
}
