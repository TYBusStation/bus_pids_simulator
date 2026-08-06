import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

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

  final Map<String, Size> _boundingBoxes = {};
  final Map<String, double> _originalFontSizes = {};
  final Map<String, String> _layerInitialText = {};
  final Map<String, bool> _layerIsVertical = {};
  final Set<String> _allTextLayers = {};
  final Set<String> _paragraphLayers = {};

  final Map<String, double> _calculatedSizes = {};
  Uint8List? _lastParsedData;
  String? _lastTextMapHash;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) _handleAnimationComplete();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RouteAnalysisProvider>().addListener(_onLedEventChanged);
      }
    });
  }

  @override
  void dispose() {
    try {
      context.read<RouteAnalysisProvider>().removeListener(_onLedEventChanged);
    } catch (_) {}
    _controller.dispose();
    super.dispose();
  }

  void _onLedEventChanged() {
    if (!mounted) return;
    final event = context.read<RouteAnalysisProvider>().currentLedEvent;
    if (event.timestamp != _lastEventTime) {
      _lastEventTime = event.timestamp;
      if (event.type == LedBroadcastType.slogan) return;
      setState(() {
        _isPriorityMode = true;
        _activeType = event.type;
      });
      _controller.stop();
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
    if (_lastParsedData == data) return;
    _lastParsedData = data;

    _boundingBoxes.clear();
    _originalFontSizes.clear();
    _layerInitialText.clear();
    _layerIsVertical.clear();
    _allTextLayers.clear();
    _paragraphLayers.clear();

    try {
      final json = jsonDecode(utf8.decode(data));
      for (var layer in (json['layers'] as List)) {
        if (layer['t'] != null && layer['t']['d'] != null) {
          var doc = layer['t']['d']['k'][0]['s'];
          String name = layer['nm'].toString();
          _allTextLayers.add(name);

          if (doc['sz'] != null &&
              (doc['sz'][0].toDouble() > 0 || doc['sz'][1].toDouble() > 0)) {
            _paragraphLayers.add(name);
            _boundingBoxes[name] = Size(
              doc['sz'][0].toDouble(),
              doc['sz'][1].toDouble(),
            );
          }

          if (doc['s'] != null) _originalFontSizes[name] = doc['s'].toDouble();
          if (doc['t'] != null) _layerInitialText[name] = doc['t'].toString();
          _layerIsVertical[name] = (doc['vt'] == 1);
        }
      }
    } catch (_) {}
  }

  String _getProcessedText(String initial, Map<String, String> map, bool vert) {
    String res = initial.replaceAll('\r', '').replaceAll('\n', ' ');
    final sortedKeys = map.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (var k in sortedKeys) {
      res = res.replaceAll('{$k}', map[k] ?? "");
    }
    if (vert) return res.replaceAll(RegExp(r'\s+'), '').split('').join('\n');
    return res.trim();
  }

  void _precalculateSizesIfNeeded(Map<String, String> textMap) {
    String currentHash = textMap.values.join('|') + _activeType.toString();
    if (_lastTextMapHash == currentHash) return;
    _lastTextMapHash = currentHash;

    _calculatedSizes.clear();
    for (String layer in _paragraphLayers) {
      double origSize = _originalFontSizes[layer] ?? 24.0;
      Size box = _boundingBoxes[layer]!;
      bool isVert = _layerIsVertical[layer] ?? false;
      String processed = _getProcessedText(
        _layerInitialText[layer] ?? "",
        textMap,
        isVert,
      );

      double maxAllowedWidth = box.width * 0.90;
      double bestSize = origSize;

      for (double s = origSize; s >= 8.0; s -= 1.0) {
        final tp = TextPainter(
          text: TextSpan(
            text: processed,
            style: TextStyle(
              fontSize: s,
              height: 1.0,
              fontFamily: "Noto Sans TC",
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: isVert ? 100 : 1,
        )..layout();

        bestSize = s;
        if (!isVert && tp.width <= maxAllowedWidth) break;
        if (isVert && tp.height <= box.height * 0.95) break;
      }
      _calculatedSizes[layer] = bestSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<StatusChangeNotifier>().currentStatus;
    final analysis = context.watch<RouteAnalysisProvider>();
    final currentEvent = analysis.currentLedEvent;
    final displayType = _isPriorityMode ? _activeType : LedBroadcastType.slogan;

    Uint8List? activeLottie = displayType == LedBroadcastType.next
        ? Static.settings.lottieNext
        : (displayType == LedBroadcastType.arrival
              ? Static.settings.lottieArrival
              : Static.settings.lottieSlogan);

    if (activeLottie == null)
      return const Scaffold(backgroundColor: Colors.black);

    _parseLottieStructure(activeLottie);
    Map<String, String> textMap = analysis.getFormattedVariables(
      currentEvent,
      status,
    );
    _precalculateSizesIfNeeded(textMap);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Lottie.memory(
          activeLottie,
          controller: _controller,
          key: ValueKey("${displayType}_${activeLottie.hashCode}"),
          onLoaded: (comp) {
            _controller.duration = comp.duration;
            _controller.stop();
            _controller.forward(from: 0);
          },
          delegates: LottieDelegates(
            textStyle: (fontStyle) => TextStyle(
              fontFamily: fontStyle.fontFamily,
              fontFamilyFallback: const ["Noto Sans TC"],
              height: 1.0,
              leadingDistribution: TextLeadingDistribution.even,
              color: Colors.white,
            ),
            values: [
              ..._allTextLayers.map(
                (name) => ValueDelegate.text(
                  [name, '**'],
                  value: _getProcessedText(
                    _layerInitialText[name] ?? "",
                    textMap,
                    _layerIsVertical[name] ?? false,
                  ),
                ),
              ),
              ..._paragraphLayers.map(
                (name) => ValueDelegate.textSize(
                  [name, '**'],
                  value:
                      _calculatedSizes[name] ??
                      _originalFontSizes[name] ??
                      24.0,
                ),
              ),
              ..._paragraphLayers.map(
                (name) => ValueDelegate.transformPosition(
                  [name, '**'],
                  callback: (frameInfo) {
                    final double boxHeight = _boundingBoxes[name]?.height ?? 0;
                    final double currentSize =
                        _calculatedSizes[name] ??
                        _originalFontSizes[name] ??
                        24.0;
                    double yDiff = (currentSize - boxHeight) * 0.5;
                    double opticalCorrection = -(currentSize * 0.08);
                    final Offset basePos =
                        Offset.lerp(
                          frameInfo.startValue ?? Offset.zero,
                          frameInfo.endValue ?? Offset.zero,
                          frameInfo.interpolatedKeyframeProgress,
                        ) ??
                        (frameInfo.startValue ?? Offset.zero);
                    return basePos + Offset(0, yDiff + opticalCorrection);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
