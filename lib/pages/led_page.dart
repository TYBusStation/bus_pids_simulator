import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  int _sloganIndex = 0;
  DateTime? _lastEventTime;
  List<String> _priorityQueue = [];
  bool _isPriorityLooping = false;
  String _currentText = "";
  bool _isPriorityMode = false;
  bool _isBlanking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nextSlogan();
      context.read<RouteAnalysisProvider>().addListener(_onLedEventChanged);
    });
  }

  @override
  void dispose() {
    context.read<RouteAnalysisProvider>().removeListener(_onLedEventChanged);
    super.dispose();
  }

  void _onLedEventChanged() {
    if (!mounted) return;
    final event = context.read<RouteAnalysisProvider>().currentLedEvent;

    if (event.type != LedBroadcastType.slogan &&
        event.timestamp != _lastEventTime) {
      _lastEventTime = event.timestamp;
      _startPriorityBroadcast(event);
    } else if (event.type == LedBroadcastType.slogan && _isPriorityMode) {
      setState(() {
        _isPriorityMode = false;
        _isPriorityLooping = false;
        _priorityQueue.clear();
        _nextSlogan();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<StatusChangeNotifier>(
        builder: (context, statusNotifier, child) {
          final isOnDuty =
              statusNotifier.currentStatus.dutyStatus == DutyStatus.onDuty;
          String display = _isBlanking ? "" : _currentText;

          return Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.98,
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF101010),
                border: Border.all(color: const Color(0xFF999999), width: 12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  reverseDuration: Duration.zero,
                  transitionBuilder: (child, animation) {
                    final key = (child.key as ValueKey<String>?)?.value;
                    if (_isPriorityMode && key != null && key != "") {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      );
                    }
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: (!isOnDuty || (display.isEmpty && !_isBlanking))
                      ? const SizedBox.expand(key: ValueKey(''))
                      : RepaintBoundary(
                          key: ValueKey(display),
                          child: LedContent(
                            text: display,
                            isPriority: _isPriorityMode,
                            onComplete: _handleContentComplete,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _startPriorityBroadcast(LedEvent event) {
    setState(() {
      _isPriorityMode = true;
      _isBlanking = false;
      _priorityQueue.clear();
      if (event.type == LedBroadcastType.next) {
        _priorityQueue = [
          "下一站",
          if (event.isTerminal) "終點站",
          event.name,
          event.nameEn,
        ];
        _isPriorityLooping = false;
      } else if (event.type == LedBroadcastType.arrival) {
        _priorityQueue = [event.name, event.nameEn, "到了"];
        _isPriorityLooping = true;
      }
      _currentText = _priorityQueue.isNotEmpty
          ? _priorityQueue.removeAt(0)
          : "";
    });
  }

  void _handleContentComplete() {
    if (!mounted) return;

    setState(() {
      _isBlanking = true;
      _currentText = "";
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isBlanking = false;
        if (_isPriorityMode) {
          if (_priorityQueue.isNotEmpty) {
            _currentText = _priorityQueue.removeAt(0);
          } else if (_isPriorityLooping) {
            final ev = context.read<RouteAnalysisProvider>().currentLedEvent;
            if (ev.type == LedBroadcastType.arrival) {
              _priorityQueue = [ev.name, ev.nameEn, "到了"];
              _currentText = _priorityQueue.removeAt(0);
            } else {
              _isPriorityMode = false;
              _nextSlogan();
            }
          } else {
            _isPriorityMode = false;
            _nextSlogan();
          }
        } else {
          _nextSlogan();
        }
      });
    });
  }

  void _nextSlogan() {
    final statusProvider = context.read<StatusChangeNotifier>();
    final analysisProvider = context.read<RouteAnalysisProvider>();

    List<String> slogans = List.from(Static.sloganList);

    if (Static.showStationListSlogan) {
      final stations = statusProvider.currentStatus.direction == Direction.go
          ? statusProvider.currentStatus.route.stations.go
          : statusProvider.currentStatus.route.stations.back;
      final nextStation = analysisProvider.currentAnalysis?.nextStation;

      if (nextStation != null) {
        int idx = stations.indexWhere((s) => s.order == nextStation.order);
        if (idx != -1) {
          slogans.add(
            "即將接近：${stations.skip(idx).take(5).map((s) => s.name).join(">")}...下車的乘客請準備",
          );
        }
      }
    }

    if (slogans.isEmpty) {
      _currentText = "";
      return;
    }

    _currentText = slogans[_sloganIndex % slogans.length];
    _sloganIndex++;
  }
}

class LedContent extends StatefulWidget {
  final String text;
  final bool isPriority;
  final VoidCallback onComplete;

  const LedContent({
    super.key,
    required this.text,
    required this.isPriority,
    required this.onComplete,
  });

  @override
  State<LedContent> createState() => _LedContentState();
}

class _LedContentState extends State<LedContent>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animation;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animation = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted || widget.text.isEmpty) return;
    await Future.delayed(const Duration(seconds: 1));
    final RenderBox? box =
        _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;

    double textW = box.size.width;
    double viewW = _scrollController.position.viewportDimension;
    double stopOffset = textW - (viewW / 2);
    bool shouldScroll = widget.isPriority ? textW > (viewW - 40) : true;

    if (!shouldScroll) {
      await Future.delayed(const Duration(seconds: 2));
      widget.onComplete();
      return;
    }

    double totalDist = widget.isPriority
        ? (stopOffset + 20)
        : textW + (viewW / 2);
    _animation.duration = Duration(
      milliseconds: (totalDist / Static.ledScrollSpeed * 1000).toInt(),
    );
    _animation.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animation.value * totalDist);
      }
    });

    _animation.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: Colors.black,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                SizedBox(width: widget.isPriority ? 20 : constraints.maxWidth),
                Text(
                  key: _textKey,
                  widget.text,
                  style: const TextStyle(
                    fontFamily: 'unifont',
                    fontSize: 165,
                    color: Color(0xFFFF0000),
                    height: 1.0,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(width: constraints.maxWidth * 2),
              ],
            ),
          ),
        );
      },
    );
  }
}
