import 'dart:js_interop';

import 'package:bus_pids_simulator/utils/web_interop.dart';
import 'package:web/web.dart' as web;

@JS('hideFlutterLoader')
external void hideFlutterLoaderJS();

class WebInteropWeb implements WebInterop {
  @override
  void hideFlutterLoader() {
    hideFlutterLoaderJS();
  }

  @override
  void toggleFullscreen() {
    final doc = web.document;
    if (doc.fullscreenElement == null) {
      doc.documentElement?.requestFullscreen();
    } else {
      doc.exitFullscreen();
    }
  }
}

WebInterop getWebInterop() => WebInteropWeb();
