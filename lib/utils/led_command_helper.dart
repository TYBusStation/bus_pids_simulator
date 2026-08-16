import 'dart:ui' as ui;

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';

import '../data/led_sequence.dart';
import 'static.dart';

class LedCommandResult {
  final String command;
  final int width;
  final double proportionalSpeed;

  LedCommandResult(this.command, this.width, this.proportionalSpeed);
}

class LedCommandHelper {
  static Future<LedCommandResult> generateCommand({
    required String text,
    required LedSequence config,
  }) async {
    const int targetHeight = 32;
    int finalColor = (config.color == -1)
        ? Static.settings.ledColor
        : config.color;
    double baseSpeed = (config.scrollSpeed == -1)
        ? Static.settings.ledScrollSpeed
        : config.scrollSpeed;
    double proportionalSpeed = (baseSpeed / 150.0) * targetHeight;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32.0,
          fontFamily: 'unifont',
          height: 1.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    int w = tp.width.ceil();
    if (w < 8) w = 8;
    if (w % 8 != 0) w += (8 - (w % 8));
    tp.paint(canvas, Offset.zero);

    final img = await recorder.endRecording().toImage(w, targetHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = byteData!.buffer.asUint8List();

    List<int> bytes = [];
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < w; x += 8) {
        int b = 0;
        for (int i = 0; i < 8; i++) {
          int px = x + i;
          if (px < w && rgba[((y * w + px) * 4) + 3] > 128) b |= (1 << (7 - i));
        }
        bytes.add(b);
      }
    }

    String hexColor = finalColor
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    int baseMode = (w <= 256 && !config.forceLongEntry) ? 1 : 0;

    String cmd =
        "I:$hexColor|S:${proportionalSpeed.toStringAsFixed(2)}|W:$w|M:$baseMode|ES:${config.entryShort.index}|EL:${config.entryLong.index}|EP:${config.entrySpeed.toInt()}|T:${config.stayMs}|FL:${config.forceLongEntry ? 1 : 0}|D:${hex.encode(bytes)}\n";

    return LedCommandResult(cmd, w, proportionalSpeed);
  }
}
