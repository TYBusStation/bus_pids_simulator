import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/led_sequence.dart';
import '../data/status.dart';
import '../utils/led_command_helper.dart';
import '../utils/static.dart';
import '../widgets/route_analysis_provider.dart';
import '../widgets/serial_provider.dart';
import '../widgets/status_provider.dart';

class LedPage extends StatefulWidget {
  const LedPage({super.key});

  @override
  State<LedPage> createState() => _LedPageState();
}

class _LedPageState extends State<LedPage> {
  List<LedSequence> _activeQueue = [];
  int _queueIndex = 0;
  int _sloganIndex = 0;
  DateTime? _lastEventTime;
  bool _isPriorityMode = false;
  bool _isBlanking = false;

  String _currentText = "";
  LedSequence? _currentConfig;

  String _cachedSloganText = "";
  String? _lastSloganCacheKey;

  StreamSubscription? _serialSubscription;
  String _serialBuffer = "";

  @override
  void initState() {
    super.initState();
    _nextSlogan();
    context.read<RouteAnalysisProvider>().addListener(_onLedEventChanged);
    Static.settings.addListener(_onSettingsChanged);

    final serial = context.read<SerialProvider>();
    _serialSubscription = serial.receiveStream.listen((data) {
      _serialBuffer += data;
      if (_serialBuffer.contains("FIN")) {
        _serialBuffer = "";
        _onSequenceComplete();
      }
      if (_serialBuffer.length > 300) _serialBuffer = "";
    });
  }

  @override
  void dispose() {
    _serialSubscription?.cancel();
    Static.settings.removeListener(_onSettingsChanged);
    try {
      context.read<RouteAnalysisProvider>().removeListener(_onLedEventChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _applyNewContent(String text, LedSequence config) async {
    if (!mounted) return;

    setState(() {
      _isBlanking = true;
      _currentText = text;
      _currentConfig = config;
    });

    final serial = context.read<SerialProvider>();

    if (serial.isConnected) {
      try {
        final result = await LedCommandHelper.generateCommand(
          text: text,
          config: config,
        );
        serial.sendLedImageRaw(result.command);
      } catch (e) {
        _onSequenceComplete();
      }
    }

    if (mounted) setState(() => _isBlanking = false);
  }

  void _onSequenceComplete() {
    if (!mounted) return;

    if (_isPriorityMode) {
      _queueIndex++;
      _updateText(context.read<RouteAnalysisProvider>().currentLedEvent);
    } else {
      _nextSlogan();
    }
  }

  void _onLedEventChanged() {
    final event = context.read<RouteAnalysisProvider>().currentLedEvent;
    if (event.timestamp != _lastEventTime &&
        event.type != LedBroadcastType.slogan) {
      if (event.type == LedBroadcastType.arrival &&
          !Static.settings.enableArrivalLedBroadcast) {
        return;
      }

      _lastEventTime = event.timestamp;
      _startPrioritySequence(event);
    }
  }

  void _startPrioritySequence(LedEvent event) {
    if (event.customSequence != null && event.customSequence!.isNotEmpty) {
      _activeQueue = List.from(event.customSequence!);
    } else {
      _activeQueue = List.from(
        event.type == LedBroadcastType.next
            ? Static.settings.ledNextStationSeq
            : Static.settings.ledArrivalSeq,
      );
    }

    _queueIndex = 0;
    _isPriorityMode = true;
    _updateText(event);
  }

  void _updateText(LedEvent event) {
    if (_queueIndex < _activeQueue.length) {
      final config = _activeQueue[_queueIndex];
      String res = context.read<RouteAnalysisProvider>().formatTemplate(
        config.template,
        event,
        context.read<StatusChangeNotifier>().currentStatus,
      );
      if (res.trim().isEmpty) {
        _queueIndex++;
        _updateText(event);
      } else {
        _applyNewContent(res, config);
      }
    } else {
      _isPriorityMode = false;
      _nextSlogan();
    }
  }

  void _nextSlogan() {
    if (_isPriorityMode) return;
    final status = context.read<StatusChangeNotifier>().currentStatus;
    final provider = context.read<RouteAnalysisProvider>();
    final analysis = provider.currentAnalysis;
    final now = DateTime.now();

    List<LedSequence> slogans = List.from(Static.settings.sloganList);

    if (Static.settings.showStationListSlogan &&
        status.dutyStatus == DutyStatus.onDuty) {
      final stations = status.direction == Direction.go
          ? status.route.stations.go
          : status.route.stations.back;
      if (analysis?.nextStation != null) {
        String cacheKey =
            "${now.minute}_${analysis!.nextStation!.order}_${status.route.name}";
        if (_lastSloganCacheKey == cacheKey) {
          slogans.add(LedSequence(template: _cachedSloganText));
        } else {
          int idx = stations.indexWhere(
            (s) => s.order == analysis.nextStation!.order,
          );
          if (idx != -1) {
            final double avgSpeedMs = provider.getEffectiveSpeedMs();
            double cumulativeSeconds =
                (analysis.distToNextStation ?? 0) / avgSpeedMs;
            List<String> subItems = [];
            for (int i = 0; i < Static.settings.nextStationCount; i++) {
              int targetIdx = idx + i;
              if (targetIdx >= stations.length) break;
              final s = stations[targetIdx];
              if (i > 0) {
                double posPrev =
                    analysis.stationPositions[stations[targetIdx - 1].order] ??
                    0;
                double posCurr = analysis.stationPositions[s.order] ?? 0;
                cumulativeSeconds +=
                    ((posCurr - posPrev).abs() * 1000 / avgSpeedMs) + 50;
              }
              DateTime est = now.add(
                Duration(seconds: cumulativeSeconds.round()),
              );
              String sub = Static.settings.nextStationSubSequence
                  .join("")
                  .replaceAll('{name}', s.name)
                  .replaceAll('{nameEn}', s.nameEn)
                  .replaceAll(
                    '{min}',
                    (cumulativeSeconds / 60).ceil().toString(),
                  )
                  .replaceAll('{TimeHH}', est.hour.toString().padLeft(2, '0'))
                  .replaceAll(
                    '{TimeMM}',
                    est.minute.toString().padLeft(2, '0'),
                  );
              subItems.add(sub);
            }
            _cachedSloganText = Static.settings.nextStationListSequence
                .join("")
                .replaceAll(
                  '{next_stations}',
                  subItems.join(Static.settings.nextStationSeparator),
                );
            _lastSloganCacheKey = cacheKey;
            slogans.add(LedSequence(template: _cachedSloganText));
          }
        }
      }
    }

    if (slogans.isNotEmpty) {
      final config = slogans[_sloganIndex % slogans.length];
      String res = provider.formatTemplate(
        config.template,
        LedEvent(type: LedBroadcastType.slogan, name: "", nameEn: ""),
        status,
      );
      _sloganIndex++;
      _applyNewContent(res, config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Consumer<SerialProvider>(
              builder: (context, serial, child) {
                return serial.isConnected
                    ? _buildConnectedStatus()
                    : _buildVirtualLed();
              },
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Consumer<SerialProvider>(
              builder: (context, serial, child) {
                return InkWell(
                  onTap: () => serial.connect(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          serial.isConnected ? Icons.usb : Icons.usb_off,
                          color: serial.isConnected ? Colors.green : Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          serial.status,
                          style: TextStyle(
                            color: serial.isConnected
                                ? Colors.green
                                : Colors.red,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedStatus() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.usb, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        const Text(
          "實體 LED 控制器已連線",
          style: TextStyle(
            color: Colors.green,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "正在播放：$_currentText",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildVirtualLed() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.98,
      height: Static.settings.ledHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        border: Border.all(color: const Color(0xFF999999), width: 12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRect(
        child: RepaintBoundary(
          child: (_isBlanking || _currentText.isEmpty)
              ? const SizedBox.expand()
              : LedContent(
                  key: ValueKey(
                    "LED_${_currentText}_${_isPriorityMode}_$_queueIndex",
                  ),
                  text: _currentText,
                  config: _currentConfig ?? LedSequence(template: ""),
                  containerHeight: Static.settings.ledHeight,
                  onComplete: () {
                    if (!context.read<SerialProvider>().isConnected) {
                      _onSequenceComplete();
                    }
                  },
                ),
        ),
      ),
    );
  }
}

class LedContent extends StatefulWidget {
  final String text;
  final LedSequence config;
  final double containerHeight;
  final VoidCallback onComplete;

  const LedContent({
    super.key,
    required this.text,
    required this.config,
    required this.containerHeight,
    required this.onComplete,
  });

  @override
  State<LedContent> createState() => _LedContentState();
}

class _LedContentState extends State<LedContent> with TickerProviderStateMixin {
  late ScrollController _scroll;
  late AnimationController _scrollAnim, _entryAnim;
  final GlobalKey _key = GlobalKey();
  bool _isLong = false, _isReady = false;
  Offset _entryOffset = Offset.zero;
  Alignment _align = Alignment.center;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _scrollAnim = AnimationController(vsync: this);
    _entryAnim = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.config.entrySpeed.toInt().clamp(10, 5000),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLayout());
  }

  void _initLayout() async {
    if (!mounted) return;
    final rb = _key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;

    double tw = rb.size.width;
    double vw = MediaQuery.of(context).size.width * 0.98;
    _isLong = tw > (vw - 80);

    bool effectiveIsLong =
        _isLong || widget.config.entryShort == LedEntryShort.asLongSetting;

    if (mounted) {
      setState(() {
        if (!effectiveIsLong) {
          _align = (widget.config.entryShort.name.contains('Left'))
              ? Alignment.centerLeft
              : Alignment.center;
          _entryOffset = (widget.config.entryShort.name.contains('top'))
              ? const Offset(0, -1)
              : (widget.config.entryShort.name.contains('bottom')
                    ? const Offset(0, 1)
                    : const Offset(1, 0));
        } else {
          _align = Alignment.centerLeft;
          _isLong = true;
          _entryOffset = (widget.config.entryLong == LedEntryLong.rightScrollIn)
              ? Offset.zero
              : (widget.config.entryLong == LedEntryLong.topLeftScroll
                    ? const Offset(0, -1)
                    : (widget.config.entryLong == LedEntryLong.bottomLeftScroll
                          ? const Offset(0, 1)
                          : const Offset(1, 0)));
        }
        _isReady = true;
      });
    }

    if (widget.config.entryLong == LedEntryLong.rightScrollIn &&
        effectiveIsLong) {
      _startScroll(tw, vw);
    } else {
      try {
        await _entryAnim.forward().orCancel;
        await Future.delayed(Duration(milliseconds: widget.config.stayMs));
        if (!mounted) return;
        if (effectiveIsLong) {
          _startScroll(tw, vw);
        } else {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) widget.onComplete();
        }
      } catch (_) {}
    }
  }

  void _startScroll(double tw, double vw) {
    if (!mounted) return;
    double dist = tw + vw;
    double speed = widget.config.scrollSpeed > 0
        ? widget.config.scrollSpeed
        : Static.settings.ledScrollSpeed;

    _scrollAnim.duration = Duration(
      milliseconds: (dist / speed * 1000).toInt().clamp(100, 60000),
    );

    _scrollAnim.addListener(() {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scrollAnim.value * dist);
      }
    });

    _scrollAnim
        .forward()
        .then((_) {
          if (mounted) widget.onComplete();
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _scrollAnim.stop();
    _entryAnim.stop();
    _scroll.dispose();
    _scrollAnim.dispose();
    _entryAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double fontSize = (widget.containerHeight - 24).clamp(0.0, 500.0) * 0.75;
    return Opacity(
      opacity: _isReady ? 1.0 : 0.0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: _entryOffset,
          end: Offset.zero,
        ).animate(_entryAnim),
        child: Container(
          alignment: _align,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.config.entryLong == LedEntryLong.rightScrollIn &&
                    _isLong)
                  SizedBox(width: MediaQuery.of(context).size.width),
                Text(
                  widget.text,
                  key: _key,
                  style: TextStyle(
                    fontFamily: 'unifont',
                    fontSize: fontSize,
                    color: Color(
                      widget.config.color > 0
                          ? widget.config.color
                          : Static.settings.ledColor,
                    ),
                    height: 1.0,
                  ),
                ),
                if (_isLong) SizedBox(width: MediaQuery.of(context).size.width),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
