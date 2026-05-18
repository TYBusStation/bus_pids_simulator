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

  @override
  Future<void> lockLandscape() async {
    try {
      final doc = web.document;
      final screen = web.window.screen;

      if (doc.fullscreenElement == null) {
        await doc.documentElement?.requestFullscreen().toDart;
      }

      await screen.orientation.lock('landscape').toDart;

      print("螢幕鎖定成功");
    } catch (e) {
      print("螢幕鎖定失敗或瀏覽器不支援: $e");

      toggleFullscreen();
    }
  }
}

WebInterop getWebInterop() => WebInteropWeb();
