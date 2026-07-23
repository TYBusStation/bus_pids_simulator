import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

Future<void> downloadFile(Uint8List bytes, String fileName) async {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

void downloadFileFromUrl(String url, String fileName) {
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
}

Future<void> toggleFullscreen(bool enable) async {
  try {
    if (enable) {
      html.document.documentElement?.requestFullscreen();
    } else {
      if (html.document.fullscreenElement != null) {
        html.document.exitFullscreen();
      }
    }
  } catch (e) {
    debugPrint("Web Fullscreen Error: $e");
  }
}

Future<void> setOrientation(bool landscape) async {
  try {
    if (landscape) {
      await html.document.documentElement?.requestFullscreen();
      await html.window.screen?.orientation?.lock('landscape');
    } else {
      html.window.screen?.orientation?.unlock();
    }
  } catch (e) {
    debugPrint("Web Orientation Error: $e");
  }
}
