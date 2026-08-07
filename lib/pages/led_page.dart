import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/led_sequence.dart';
import '../data/status.dart';
import '../utils/static.dart';
import '../widgets/route_analysis_provider.dart';
import '../widgets/status_provider.dart';

class LedPage extends StatefulWidget {
  const LedPage({super.key});

  @override
  State<LedPage> createState() => _LedPageState();
}

class _LedPageState extends State<LedPage> {
  List<LedSequence> _activeQueue = [];
  int _queueIndex = 0, _sloganIndex = 0;
  DateTime? _lastEventTime;
  bool _isPriorityMode = false, _isBlanking = false;
  String _currentText = "";
  LedSequence? _currentConfig;

  @override
  void initState() {
    super.initState();
    _nextSlogan();
    context.read<RouteAnalysisProvider>().addListener(_onLedEventChanged);
    Static.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    context.read<RouteAnalysisProvider>().removeListener(_onLedEventChanged);
    Static.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onLedEventChanged() {
    final event = context.read<RouteAnalysisProvider>().currentLedEvent;
    if (event.timestamp != _lastEventTime &&
        event.type != LedBroadcastType.slogan) {
      _lastEventTime = event.timestamp;
      _startPrioritySequence(event);
    }
  }

  void _startPrioritySequence(LedEvent event) {
    _activeQueue = List.from(
      event.type == LedBroadcastType.next
          ? Static.settings.ledNextStationSeq
          : Static.settings.ledArrivalSeq,
    );
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
        setState(() {
          _isBlanking = true;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          setState(() {
            _currentText = res;
            _currentConfig = config;
            _isBlanking = false;
          });
        });
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
    List<LedSequence> slogans = List.from(Static.settings.sloganList);

    if (Static.settings.showStationListSlogan &&
        status.dutyStatus == DutyStatus.onDuty) {
      final stations = status.direction == Direction.go
          ? status.route.stations.go
          : status.route.stations.back;
      if (analysis?.nextStation != null) {
        int idx = stations.indexWhere(
          (s) => s.order == analysis!.nextStation!.order,
        );
        if (idx != -1) {
          final now = DateTime.now();
          final double avgSpeedMs = provider.getEffectiveSpeedMs();
          double cumulativeSeconds =
              (analysis!.distToNextStation ?? 0) / avgSpeedMs;
          List<String> subItems = [];

          for (int i = 0; i < Static.settings.nextStationCount; i++) {
            int targetIdx = idx + i;
            if (targetIdx >= stations.length) break;

            final s = stations[targetIdx];
            if (i > 0) {
              double posPrev =
                  analysis.stationPositions[stations[targetIdx - 1].order] ?? 0;
              double posCurr = analysis.stationPositions[s.order] ?? 0;
              double segmentDist = (posCurr - posPrev).abs() * 1000;
              cumulativeSeconds += (segmentDist / avgSpeedMs) + 50;
            }

            DateTime est = now.add(
              Duration(seconds: cumulativeSeconds.round()),
            );
            String minStr = (cumulativeSeconds / 60).ceil().toString();
            String hhStr = est.hour.toString().padLeft(2, '0');
            String mmStr = est.minute.toString().padLeft(2, '0');

            String sub = Static.settings.nextStationSubSequence
                .join("")
                .replaceAll('{name}', s.name)
                .replaceAll('{nameEn}', s.nameEn)
                .replaceAll('{min}', minStr)
                .replaceAll('{TimeHH}', hhStr)
                .replaceAll('{TimeMM}', mmStr);
            subItems.add(sub);
          }

          slogans.add(
            LedSequence(
              template: Static.settings.nextStationListSequence
                  .join("")
                  .replaceAll(
                    '{next_stations}',
                    subItems.join(Static.settings.nextStationSeparator),
                  ),
            ),
          );
        }
      }
    }

    if (slogans.isEmpty) {
      _currentText = "";
      _currentConfig = null;
    } else {
      final config = slogans[_sloganIndex % slogans.length];
      _currentText = provider.formatTemplate(
        config.template,
        LedEvent(type: LedBroadcastType.slogan, name: "", nameEn: ""),
        status,
      );
      _currentConfig = config;
      _sloganIndex++;
    }
    if (mounted) {
      setState(() {
        _isBlanking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.98,
          height: Static.settings.ledHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            border: Border.all(color: const Color(0xFF999999), width: 12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRect(
            child: (_isBlanking || _currentText.isEmpty)
                ? const SizedBox.expand()
                : LedContent(
                    key: ValueKey(
                      "LED_${_currentText}_${_isPriorityMode}_${_queueIndex}",
                    ),
                    text: _currentText,
                    config: _currentConfig ?? LedSequence(template: ""),
                    containerHeight: Static.settings.ledHeight,
                    onComplete: () {
                      if (_isPriorityMode) {
                        _queueIndex++;
                        _updateText(
                          context.read<RouteAnalysisProvider>().currentLedEvent,
                        );
                      } else
                        _nextSlogan();
                    },
                  ),
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
      duration: Duration(milliseconds: widget.config.entrySpeed.toInt()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLayout());
  }

  void _initLayout() async {
    if (!mounted) return;
    final rb = _key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    double tw = rb.size.width, vw = MediaQuery.of(context).size.width * 0.98;
    _isLong = tw > (vw - 80);
    setState(() {
      if (!_isLong) {
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
    if (widget.config.entryLong == LedEntryLong.rightScrollIn && _isLong)
      _startScroll(tw, vw);
    else {
      await _entryAnim.forward();
      await Future.delayed(Duration(milliseconds: widget.config.stayMs));
      if (_isLong)
        _startScroll(tw, vw);
      else {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) widget.onComplete();
      }
    }
  }

  void _startScroll(double tw, double vw) {
    double dist = tw + vw,
        speed = widget.config.scrollSpeed > 0
            ? widget.config.scrollSpeed
            : Static.settings.ledScrollSpeed;
    _scrollAnim.duration = Duration(
      milliseconds: (dist / speed * 1000).toInt(),
    );
    _scrollAnim.addListener(() {
      if (_scroll.hasClients) _scroll.jumpTo(_scrollAnim.value * dist);
    });
    _scrollAnim.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _scrollAnim.dispose();
    _entryAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double fontSize = (widget.containerHeight - 24).clamp(0.0, 2000.0) * 0.75;
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
