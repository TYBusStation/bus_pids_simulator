import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  bool _isInitialLoading = true;
  Uint8List? _displayData;
  LedBroadcastType? _displayType;
  bool _isPreparing = false;
  String? _lastTextMapHash;

  final Map<String, Size> _boundingBoxes = {};
  final Map<String, double> _originalFontSizes = {};
  final Map<String, String> _layerInitialText = {};
  final Map<String, bool> _layerIsVertical = {};
  final Map<String, String> _layerFontFamily = {};
  final Set<String> _allTextLayers = {};
  final Set<String> _paragraphLayers = {};
  final Map<String, Map<String, String>> _fontMetadataMap = {};
  final Map<String, TextStyle> _baseStyleCache = {};
  final Map<String, double> _calculatedSizes = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) _handleAnimationComplete();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RouteAnalysisProvider>().addListener(_onLedEventChanged);
        _updateActiveLottie();
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
      if (event.type != LedBroadcastType.slogan) {
        _isPriorityMode = true;
        _activeType = event.type;
        _controller.stop();
        _updateActiveLottie();
      }
    }
  }

  void _handleAnimationComplete() {
    if (!mounted) return;
    if (_isPriorityMode && _activeType == LedBroadcastType.next) {
      _isPriorityMode = false;
      _activeType = LedBroadcastType.slogan;
      _updateActiveLottie();
      return;
    }
    _controller.forward(from: 0);
  }

  Future<void> _updateActiveLottie() async {
    if (_isPreparing) return;
    _isPreparing = true;

    final targetType = _isPriorityMode ? _activeType : LedBroadcastType.slogan;
    Uint8List? targetData = targetType == LedBroadcastType.next
        ? Static.settings.lottieNext
        : (targetType == LedBroadcastType.arrival
              ? Static.settings.lottieArrival
              : Static.settings.lottieSlogan);

    if (targetData == null ||
        (targetData == _displayData && !_isInitialLoading)) {
      _isPreparing = false;
      return;
    }

    await _prepareLottieBackground(targetData);

    if (mounted) {
      setState(() {
        _displayData = targetData;
        _displayType = targetType;
        _isInitialLoading = false;
        _isPreparing = false;
      });
    }
  }

  Future<void> _prepareLottieBackground(Uint8List data) async {
    final tempFontMetadata = <String, Map<String, String>>{};
    final tempBoundingBoxes = <String, Size>{};
    final tempOriginalSizes = <String, double>{};
    final tempInitialText = <String, String>{};
    final tempIsVertical = <String, bool>{};
    final tempFontFamily = <String, String>{};
    final tempAllTextLayers = <String>{};

    try {
      final json = jsonDecode(utf8.decode(data));
      if (json['fonts'] != null && json['fonts']['list'] != null) {
        List<Future> prepTasks = [];
        for (var f in (json['fonts']['list'] as List)) {
          final String fn = (f['fName']?.toString() ?? "");
          final String fam = (f['fFamily']?.toString() ?? "");
          final String w = (f['fWeight']?.toString() ?? "");
          final String s = (f['fStyle']?.toString() ?? "");
          tempFontMetadata[fn] = {'family': fam, 'weight': w, 'style': s};
          prepTasks.add(_prewarmFont(fn, fam, s, w));
        }
        await Future.wait(prepTasks);
      }

      for (var layer in (json['layers'] as List)) {
        if (layer['t'] != null && layer['t']['d'] != null) {
          var doc = layer['t']['d']['k'][0]['s'];
          String nm = layer['nm'].toString();
          tempAllTextLayers.add(nm);
          tempFontFamily[nm] = doc['f']?.toString() ?? "";
          if (doc['sz'] != null &&
              (doc['sz'][0].toDouble() > 0 || doc['sz'][1].toDouble() > 0)) {
            tempBoundingBoxes[nm] = Size(
              doc['sz'][0].toDouble(),
              doc['sz'][1].toDouble(),
            );
          }
          if (doc['s'] != null) tempOriginalSizes[nm] = doc['s'].toDouble();
          if (doc['t'] != null) tempInitialText[nm] = doc['t'].toString();
          tempIsVertical[nm] = (doc['vt'] == 1);
        }
      }

      _baseStyleCache.clear();
      _calculatedSizes.clear();
      _lastTextMapHash = null;

      _fontMetadataMap.clear();
      _fontMetadataMap.addAll(tempFontMetadata);
      _boundingBoxes.clear();
      _boundingBoxes.addAll(tempBoundingBoxes);
      _originalFontSizes.clear();
      _originalFontSizes.addAll(tempOriginalSizes);
      _layerInitialText.clear();
      _layerInitialText.addAll(tempInitialText);
      _layerIsVertical.clear();
      _layerIsVertical.addAll(tempIsVertical);
      _layerFontFamily.clear();
      _layerFontFamily.addAll(tempFontFamily);
      _allTextLayers.clear();
      _allTextLayers.addAll(tempAllTextLayers);
      _paragraphLayers.clear();
      _paragraphLayers.addAll(tempBoundingBoxes.keys);
    } catch (_) {}
  }

  Future<void> _prewarmFont(String fn, String fam, String s, String w) async {
    final weight = _resolveFontWeight(s, w, fn);
    final isItalic = s.toLowerCase().contains('italic')
        ? FontStyle.italic
        : FontStyle.normal;
    final String target = fam.isEmpty ? fn : fam;
    if (Static.settings.fontList.any(
      (f) => f.name.toLowerCase() == target.toLowerCase(),
    ))
      return;
    try {
      final googleMap = GoogleFonts.asMap();
      final normalized = target
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('-', '');
      String? mk;
      for (var k in googleMap.keys) {
        if (k.toLowerCase().replaceAll(' ', '').replaceAll('-', '') ==
            normalized) {
          mk = k;
          break;
        }
      }
      if (mk != null) {
        await GoogleFonts.pendingFonts([
          GoogleFonts.getFont(mk, fontWeight: weight, fontStyle: isItalic),
        ]);
      }
    } catch (_) {}
  }

  FontWeight _resolveFontWeight(String s, String w, String fn) {
    final str = (s + w + fn).toLowerCase().trim();
    if (str.contains('900') || str.contains('black')) return FontWeight.w900;
    if (str.contains('800') || (str.contains('extra') && str.contains('bold')))
      return FontWeight.w800;
    if (str.contains('700') || str.contains('bold')) return FontWeight.w700;
    if (str.contains('600') || str.contains('semi')) return FontWeight.w600;
    if (str.contains('500') || str.contains('medium')) return FontWeight.w500;
    if (str.contains('300') || str.contains('light')) return FontWeight.w300;
    if (str.contains('100') || str.contains('thin')) return FontWeight.w100;
    return FontWeight.normal;
  }

  TextStyle _getFinalTextStyle(String? lfn, double fs) {
    final String fn = lfn ?? "";
    final String cacheKey = "${fn}_$fs";
    if (_baseStyleCache.containsKey(cacheKey))
      return _baseStyleCache[cacheKey]!;

    final meta = _fontMetadataMap[fn] ?? {};
    final String target = (meta['family'] ?? fn).toString().trim();
    final weight = _resolveFontWeight(
      meta['style'] ?? "",
      meta['weight'] ?? "",
      fn,
    );
    final isItalic = (meta['style']?.toLowerCase().contains('italic') ?? false)
        ? FontStyle.italic
        : FontStyle.normal;

    TextStyle style;
    final normalizedTarget = target
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('-', '');
    final customIdx = Static.settings.fontList.indexWhere(
      (f) =>
          f.name.toLowerCase().replaceAll(' ', '').replaceAll('-', '') ==
          normalizedTarget,
    );

    if (customIdx != -1) {
      style = TextStyle(
        fontFamily: Static.settings.fontList[customIdx].name,
        fontWeight: weight,
        fontStyle: isItalic,
      );
    } else {
      final googleMap = GoogleFonts.asMap();
      String? mk;
      for (var k in googleMap.keys) {
        if (k.toLowerCase().replaceAll(' ', '').replaceAll('-', '') ==
            normalizedTarget) {
          mk = k;
          break;
        }
      }
      style = (mk != null)
          ? GoogleFonts.getFont(mk, fontWeight: weight, fontStyle: isItalic)
          : TextStyle(
              fontFamily: target,
              fontWeight: weight,
              fontStyle: isItalic,
            );
    }
    final finalStyle = style.copyWith(fontSize: fs);
    _baseStyleCache[cacheKey] = finalStyle;
    return finalStyle;
  }

  String _getProcessedText(String ini, Map<String, String> map, bool vert) {
    String res = ini.replaceAll('\r', '').replaceAll('\n', ' ');
    final sk = map.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (var k in sk) {
      res = res.replaceAll('{$k}', map[k] ?? "");
    }
    return vert
        ? res.replaceAll(RegExp(r'\s+'), '').split('').join('\n')
        : res.trim();
  }

  void _precalculateSizes(Map<String, String> tm) {
    String h = tm.values.join('|') + (_displayType?.toString() ?? "");
    if (_lastTextMapHash == h) return;
    _lastTextMapHash = h;
    _calculatedSizes.clear();
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (String ly in _paragraphLayers) {
      if (!_boundingBoxes.containsKey(ly)) continue;
      double maxFs = _originalFontSizes[ly] ?? 24.0;
      Size b = _boundingBoxes[ly]!;
      bool v = _layerIsVertical[ly] ?? false;
      String p = _getProcessedText(_layerInitialText[ly] ?? "", tm, v);
      final TextStyle bs = _getFinalTextStyle(_layerFontFamily[ly], 1.0);
      double lo = 8.0, hi = maxFs, best = lo;
      while (lo <= hi) {
        double mi = (lo + hi) / 2;
        tp.text = TextSpan(
          text: p,
          style: bs.copyWith(fontSize: mi),
        );
        tp.maxLines = v ? 100 : 1;
        tp.layout();
        if (v ? tp.height <= b.height * 0.95 : tp.width <= b.width * 0.90) {
          best = mi;
          lo = mi + 0.5;
        } else {
          hi = mi - 0.5;
        }
      }
      _calculatedSizes[ly] = best;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading || _displayData == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }

    final status = context.watch<StatusChangeNotifier>().currentStatus;
    final analysis = context.watch<RouteAnalysisProvider>();
    Map<String, String> tm = analysis.getFormattedVariables(
      analysis.currentLedEvent,
      status,
    );
    _precalculateSizes(tm);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Lottie.memory(
          _displayData!,
          controller: _controller,
          key: ValueKey("${_displayType}_${_displayData.hashCode}"),
          onLoaded: (c) {
            _controller.duration = c.duration;
            _controller.forward(from: 0);
          },
          delegates: LottieDelegates(
            textStyle: (lfs) {
              final baseStyle = _getFinalTextStyle(lfs.fontFamily, 24.0);
              return baseStyle.copyWith(
                color: Colors.white,
                height: 1.0,
                leadingDistribution: TextLeadingDistribution.even,
              );
            },
            values: [
              ..._allTextLayers.map((n) {
                final initial = _layerInitialText[n];
                if (initial == null)
                  return ValueDelegate.text([n, '**'], value: "");
                return ValueDelegate.text(
                  [n, '**'],
                  value: _getProcessedText(
                    initial,
                    tm,
                    _layerIsVertical[n] ?? false,
                  ),
                );
              }),
              ..._paragraphLayers.map(
                (n) => ValueDelegate.textSize(
                  [n, '**'],
                  value: (_calculatedSizes[n] ?? _originalFontSizes[n] ?? 24.0)
                      .clamp(1.0, 500.0),
                ),
              ),
              ..._paragraphLayers.map(
                (n) => ValueDelegate.transformPosition(
                  [n, '**'],
                  callback: (fi) {
                    final double bh = _boundingBoxes[n]?.height ?? 0;
                    final double cs =
                        _calculatedSizes[n] ?? _originalFontSizes[n] ?? 24.0;
                    final Offset bp =
                        Offset.lerp(
                          fi.startValue ?? Offset.zero,
                          fi.endValue ?? Offset.zero,
                          fi.interpolatedKeyframeProgress,
                        ) ??
                        (fi.startValue ?? Offset.zero);
                    return bp + Offset(0, (cs - bh) * 0.5 - (cs * 0.08));
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
