import 'package:bus_pids_simulator/utils/web_interop.dart';
import 'package:flutter/services.dart';

class WebInteropStub implements WebInterop {
  bool _isFull = false;

  @override
  void hideFlutterLoader() {}

  @override
  void toggleFullscreen() {
    _isFull = !_isFull;
    if (_isFull) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void lockLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}

WebInterop getWebInterop() => WebInteropStub();
