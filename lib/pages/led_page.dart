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
  int _queueIndex = 0;
  DateTime? _lastEventTime;
  bool _isPriorityMode = false;
  bool _isTransitioning = false;
  String _currentText = "";
  LedSequence? _currentConfig;
  int _sloganIndex = 0;
  bool _isBlanking = false;

  @override
  void initState() {
    super.initState();
    _nextSlogan();
    context.read<RouteAnalysisProvider>().addListener(_onLedEventChanged);
    Static.settingsNotifier.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    context.read<RouteAnalysisProvider>().removeListener(_onLedEventChanged);
    Static.settingsNotifier.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted && !_isPriorityMode) {
      setState(() {});
    }
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
    setState(() {
      _isPriorityMode = true;
      _isTransitioning = true;
      _isBlanking = true;
      _queueIndex = 0;
      _activeQueue = List.from(
        event.type == LedBroadcastType.next
            ? Static.ledNextStationSeq
            : Static.ledArrivalSeq,
      );
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _updateCurrentText(event);
        _isBlanking = false;
        _isTransitioning = false;
      });
    });
  }

  void _updateCurrentText(LedEvent event) {
    if (_queueIndex < _activeQueue.length) {
      final config = _activeQueue[_queueIndex];
      String processed = config.template
          .replaceAll('{name}', event.name)
          .replaceAll('{nameEn}', event.nameEn)
          .replaceAll('{terminal}', event.isTerminal ? "終點站" : "");

      if (processed.trim().isEmpty) {
        _queueIndex++;
        if (_queueIndex < _activeQueue.length) {
          _updateCurrentText(event);
        } else {
          _exitPriority();
        }
      } else {
        _currentText = processed;
        _currentConfig = config;
      }
    } else {
      _exitPriority();
    }
  }

  void _exitPriority() {
    setState(() {
      _isPriorityMode = false;
      _activeQueue = [];
      _queueIndex = 0;
      _nextSlogan();
    });
  }

  void _nextSlogan() {
    if (_isPriorityMode && !_isBlanking) return;

    final status = context.read<StatusChangeNotifier>().currentStatus;
    final analysis = context.read<RouteAnalysisProvider>().currentAnalysis;
    List<LedSequence> slogans = List.from(Static.sloganList);

    if (Static.showStationListSlogan &&
        status.dutyStatus == DutyStatus.onDuty) {
      final stations = status.direction == Direction.go
          ? status.route.stations.go
          : status.route.stations.back;
      if (analysis?.nextStation != null) {
        int idx = stations.indexWhere(
          (s) => s.order == analysis!.nextStation!.order,
        );
        if (idx != -1) {
          String text =
              "即將接近：${stations.skip(idx).take(5).map((s) => s.name).join(">")}...下車的乘客請準備";
          slogans.add(
            LedSequence(template: text, scrollSpeed: Static.ledScrollSpeed),
          );
        }
      }
    }

    if (slogans.isEmpty) {
      _currentText = "";
      _currentConfig = null;
    } else {
      final config = slogans[_sloganIndex % slogans.length];
      _currentText = config.template;
      _currentConfig = config;
      _sloganIndex++;
    }
    if (mounted) setState(() {});
  }

  void _handleComplete() {
    if (!mounted || _isTransitioning) return;

    setState(() {
      _isBlanking = true;
      _isTransitioning = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      if (_isPriorityMode) {
        final event = context.read<RouteAnalysisProvider>().currentLedEvent;
        if (_queueIndex < _activeQueue.length - 1) {
          _queueIndex++;
          _updateCurrentText(event);
          setState(() {
            _isBlanking = false;
            _isTransitioning = false;
          });
        } else if (event.type == LedBroadcastType.arrival) {
          _queueIndex = 0;
          _updateCurrentText(event);
          setState(() {
            _isBlanking = false;
            _isTransitioning = false;
          });
        } else {
          _exitPriority();
          setState(() {
            _isBlanking = false;
            _isTransitioning = false;
          });
        }
      } else {
        _nextSlogan();
        setState(() {
          _isBlanking = false;
          _isTransitioning = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.98,
          height: Static.ledHeight,
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
                      "LED_${_currentText}_${_isPriorityMode}_${_queueIndex}_${Static.ledHeight}",
                    ),
                    text: _currentText,
                    config: _currentConfig ?? LedSequence(template: ""),
                    containerHeight: Static.ledHeight,
                    onComplete: _handleComplete,
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
  late AnimationController _scrollAnim;
  late AnimationController _entryAnim;
  final GlobalKey _key = GlobalKey();
  bool _isLong = false;
  bool _isReady = false;
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

    double tw = rb.size.width;
    double vw = MediaQuery.of(context).size.width * 0.98;
    _isLong = tw > (vw - 80);

    setState(() {
      if (!_isLong) {
        switch (widget.config.entryShort) {
          case LedEntryShort.bottomLeft:
            _entryOffset = const Offset(0, 1);
            _align = Alignment.centerLeft;
          case LedEntryShort.bottomCenter:
            _entryOffset = const Offset(0, 1);
            _align = Alignment.center;
          case LedEntryShort.topLeft:
            _entryOffset = const Offset(0, -1);
            _align = Alignment.centerLeft;
          case LedEntryShort.topCenter:
            _entryOffset = const Offset(0, -1);
            _align = Alignment.center;
          case LedEntryShort.rightLeft:
            _entryOffset = const Offset(1, 0);
            _align = Alignment.centerLeft;
          case LedEntryShort.rightCenter:
            _entryOffset = const Offset(1, 0);
            _align = Alignment.center;
        }
      } else {
        switch (widget.config.entryLong) {
          case LedEntryLong.bottomLeftScroll:
            _entryOffset = const Offset(0, 1);
            _align = Alignment.centerLeft;
          case LedEntryLong.topLeftScroll:
            _entryOffset = const Offset(0, -1);
            _align = Alignment.centerLeft;
          case LedEntryLong.rightLeftScroll:
            _entryOffset = const Offset(1, 0);
            _align = Alignment.centerLeft;
          case LedEntryLong.rightScrollIn:
            _entryOffset = Offset.zero;
            _align = Alignment.centerLeft;
        }
      }
      _isReady = true;
    });

    if (widget.config.entryLong == LedEntryLong.rightScrollIn && _isLong) {
      _startScroll(tw, vw);
    } else {
      await _entryAnim.forward();
      await Future.delayed(Duration(milliseconds: widget.config.stayMs));
      if (_isLong) {
        _startScroll(tw, vw);
      } else {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) widget.onComplete();
      }
    }
  }

  void _startScroll(double tw, double vw) {
    double dist = tw + vw;
    _scrollAnim.duration = Duration(
      milliseconds: (dist / widget.config.scrollSpeed * 1000).toInt(),
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
    double innerHeight = (widget.containerHeight - 24).clamp(0.0, 2000.0);
    double fontSize = innerHeight * 0.75;
    double paddingV = (innerHeight - fontSize) / 2;
    double vw = MediaQuery.of(context).size.width * 0.98;

    return Opacity(
      opacity: _isReady ? 1.0 : 0.0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: _entryOffset,
          end: Offset.zero,
        ).animate(_entryAnim),
        child: Container(
          alignment: _align,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: paddingV),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                if (widget.config.entryLong == LedEntryLong.rightScrollIn &&
                    _isLong)
                  SizedBox(width: vw),
                Text(
                  widget.text,
                  key: _key,
                  style: TextStyle(
                    fontFamily: 'unifont',
                    fontSize: fontSize,
                    color: const Color(0xFFFF0000),
                    height: 1.0,
                  ),
                ),
                if (_isLong) SizedBox(width: vw),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
