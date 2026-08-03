import 'dart:convert';
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
  late final AnimationController _marqueeController;
  DateTime? _lastEventTime;
  bool _isPriorityMode = false;
  LedBroadcastType _activeType = LedBroadcastType.slogan;

  final Map<String, Size> _boundingBoxes = {};
  final Map<String, double> _originalFontSizes = {};
  final Map<String, String> _layerInitialText = {};
  final Map<String, String> _layerFonts = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _marqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _handleAnimationComplete();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouteAnalysisProvider>().addListener(_onLedEventChanged);
    });
  }

  @override
  void dispose() {
    _marqueeController.dispose();
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

  void _parseLottieStructure(Uint8List data) {
    _boundingBoxes.clear();
    _originalFontSizes.clear();
    _layerInitialText.clear();
    _layerFonts.clear();
    try {
      final json = jsonDecode(utf8.decode(data));
      for (var layer in (json['layers'] as List)) {
        if (layer['t'] != null && layer['t']['d'] != null) {
          var doc = layer['t']['d']['k'][0]['s'];
          String name = layer['nm'].toString();
          if (doc['sz'] != null && doc['sz'][0] > 0) {
            _boundingBoxes[name] = Size(
              doc['sz'][0].toDouble(),
              doc['sz'][1].toDouble(),
            );
          }
          if (doc['s'] != null) _originalFontSizes[name] = doc['s'].toDouble();
          if (doc['t'] != null) _layerInitialText[name] = doc['t'].toString();
          if (doc['f'] != null) _layerFonts[name] = doc['f'].toString();
        }
      }
    } catch (e) {}
  }

  String _getProcessedText(String initialText, Map<String, String> textMap) {
    String res = initialText;
    textMap.forEach((k, v) => res = res.replaceAll('{$k}', v));
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = context.watch<StatusChangeNotifier>();
    final analysisProvider = context.watch<RouteAnalysisProvider>();
    final st = statusProvider.currentStatus;
    final currentEvent = analysisProvider.currentLedEvent;
    String dest = st.direction == Direction.go
        ? st.route.destination
        : st.route.departure;
    final stations = st.direction == Direction.go
        ? st.route.stations.go
        : st.route.stations.back;
    int idx = analysisProvider.displayStation != null
        ? stations.indexWhere(
            (s) => s.order == analysisProvider.displayStation!.order,
          )
        : -1;

    Map<String, String> textMap = {
      'name': currentEvent.name,
      'nameEn': currentEvent.nameEn,
      'terminal': currentEvent.isTerminal ? "終點站" : "",
      'route_name': st.route.name,
      'route_desc': st.route.description ?? "",
      'route_dest': dest,
      'hh': DateTime.now().hour.toString().padLeft(2, '0'),
      'mm': DateTime.now().minute.toString().padLeft(2, '0'),
      'ss': DateTime.now().second.toString().padLeft(2, '0'),
    };

    for (int i = 1; i <= 15; i++) {
      String pN = "", pE = "", nN = "", nE = "";
      if (idx != -1) {
        if (idx - i >= 0) {
          pN = stations[idx - i].name;
          pE = stations[idx - i].nameEn;
        }
        if (idx + i < stations.length) {
          nN = stations[idx + i].name;
          nE = stations[idx + i].nameEn;
        }
      }
      textMap['PrevName$i'] = pN;
      textMap['PrevNameEn$i'] = pE;
      textMap['NextName$i'] = nN;
      textMap['NextNameEn$i'] = nE;
    }

    final displayType = _isPriorityMode ? _activeType : LedBroadcastType.slogan;
    Uint8List? activeLottie = displayType == LedBroadcastType.next
        ? Static.lottieNext
        : (displayType == LedBroadcastType.arrival
              ? Static.lottieArrival
              : Static.lottieSlogan);

    if (activeLottie == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("無檔案", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _marqueeController,
        builder: (context, child) {
          return Center(
            child: Lottie.memory(
              activeLottie,
              controller: _controller,
              key: ValueKey("${displayType}_$_lastEventTime"),
              onLoaded: (comp) {
                _parseLottieStructure(activeLottie);
                _controller.duration = comp.duration;
                _controller.forward(from: 0);
              },
              delegates: LottieDelegates(
                textStyle: (font) {
                  double size = 24.0;
                  for (var entry in _originalFontSizes.entries) {
                    if (font.fontFamily.contains(entry.key) ||
                        entry.key.contains(font.fontFamily)) {
                      size = entry.value;
                      break;
                    }
                  }
                  return Static.getAppFont(font.fontFamily, size, Colors.white);
                },
                text: (initialText) {
                  String res = _getProcessedText(initialText, textMap);
                  if (Static.lottieOverflowMode == "scroll") {
                    String layerName = "";
                    _layerInitialText.forEach((k, v) {
                      if (v == initialText) layerName = k;
                    });
                    if (layerName.isNotEmpty &&
                        _boundingBoxes.containsKey(layerName)) {
                      Size box = _boundingBoxes[layerName]!;
                      double fontSize = _originalFontSizes[layerName] ?? 24.0;
                      String fontName = _layerFonts[layerName] ?? "";
                      final tp = TextPainter(
                        text: TextSpan(
                          text: res,
                          style: Static.getAppFont(
                            fontName,
                            fontSize,
                            Colors.white,
                          ),
                        ),
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: box.width);
                      if (tp.height > box.height)
                        return res.replaceAll(RegExp(r'[\r\n]+'), ' ');
                    }
                  }
                  return res;
                },
                values: [
                  ..._boundingBoxes.keys.map((layerName) {
                    return ValueDelegate.position(
                      [layerName, '**'],
                      callback: (frameInfo) {
                        Offset origPos = frameInfo.startValue ?? Offset.zero;
                        if (Static.lottieOverflowMode != "scroll")
                          return origPos;
                        Size box = _boundingBoxes[layerName]!;
                        double fontSize = _originalFontSizes[layerName] ?? 24.0;
                        String fontName = _layerFonts[layerName] ?? "";
                        String rawText = _layerInitialText[layerName] ?? "";
                        String processed = _getProcessedText(rawText, textMap);

                        final tpWrap = TextPainter(
                          text: TextSpan(
                            text: processed,
                            style: Static.getAppFont(
                              fontName,
                              fontSize,
                              Colors.white,
                            ),
                          ),
                          textDirection: TextDirection.ltr,
                        )..layout(maxWidth: box.width);

                        String finalScrollText = (tpWrap.height > box.height)
                            ? processed.replaceAll(RegExp(r'[\r\n]+'), ' ')
                            : processed;
                        final tpFull = TextPainter(
                          text: TextSpan(
                            text: finalScrollText,
                            style: Static.getAppFont(
                              fontName,
                              fontSize,
                              Colors.white,
                            ),
                          ),
                          textDirection: TextDirection.ltr,
                        )..layout();

                        if (tpFull.width > box.width) {
                          double overflow = tpFull.width - box.width + 100;
                          return Offset(
                            origPos.dx - (_marqueeController.value * overflow),
                            origPos.dy,
                          );
                        }
                        return origPos;
                      },
                    );
                  }),
                  ..._boundingBoxes.keys.map((layerName) {
                    return ValueDelegate.textSize(
                      [layerName, '**'],
                      callback: (frameInfo) {
                        double origSize = _originalFontSizes[layerName] ?? 24.0;
                        if (Static.lottieOverflowMode != "shrink")
                          return origSize;
                        Size box = _boundingBoxes[layerName]!;
                        String fontName = _layerFonts[layerName] ?? "";
                        String processed = _getProcessedText(
                          _layerInitialText[layerName] ?? "",
                          textMap,
                        );
                        final tp = TextPainter(
                          text: TextSpan(
                            text: processed,
                            style: Static.getAppFont(
                              fontName,
                              origSize,
                              Colors.white,
                            ),
                          ),
                          textDirection: TextDirection.ltr,
                        )..layout(maxWidth: box.width);
                        return (tp.height > box.height)
                            ? origSize * (box.height / tp.height)
                            : origSize;
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
