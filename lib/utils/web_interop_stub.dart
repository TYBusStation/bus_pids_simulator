import 'package:bus_pids_simulator/utils/web_interop.dart';

class WebInteropStub implements WebInterop {
  @override
  void hideFlutterLoader() {}
}

WebInterop getWebInterop() => WebInteropStub();
