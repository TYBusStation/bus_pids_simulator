import 'package:bus_pids_simulator/data/led_sequence.dart';
import 'package:flutter/material.dart';

class SerialWorker {
  bool isConnected = false;
  String status = "未初始化";
  VoidCallback? onStatusChange;

  Stream<String> get receiveStream => Stream.empty();

  void init() {}

  Future<void> connect() async {}

  Future<void> sendRawCommand(String cmd) async {}

  Future<void> sendLedImage(String text, LedSequence config) async {}
}
