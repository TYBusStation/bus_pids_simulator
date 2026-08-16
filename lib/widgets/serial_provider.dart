import 'package:flutter/material.dart';

import '../data/led_sequence.dart';
import '../utils/serial_worker_stub.dart'
    if (dart.library.io) '../utils/serial_worker_mobile.dart'
    if (dart.library.html) '../utils/serial_worker_web.dart';

class SerialProvider extends ChangeNotifier {
  final SerialWorker _worker = SerialWorker();

  Stream<String> get receiveStream => _worker.receiveStream;

  bool get isConnected => _worker.isConnected;

  String get status => _worker.status;

  SerialProvider() {
    _worker.onStatusChange = notifyListeners;
    _worker.init();
  }

  Future<void> connect() async {
    await _worker.connect();
  }

  Future<void> sendLedImageRaw(String command) async {
    if (_worker.isConnected) {
      await _worker.sendRawCommand(command);
    }
  }

  Future<void> sendLedImage(String text, LedSequence config) async {
    if (_worker.isConnected) {
      await _worker.sendLedImage(text, config);
    }
  }
}
