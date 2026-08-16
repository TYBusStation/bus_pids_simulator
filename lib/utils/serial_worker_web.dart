import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webserial/webserial.dart';

import '../data/led_sequence.dart';
import 'led_command_helper.dart';

@JS()
@staticInterop
class JSReadableStreamDefaultReader {}

extension JSReadableStreamDefaultReaderExtension
    on JSReadableStreamDefaultReader {
  external JSPromise<JSObject> read();

  external void releaseLock();
}

@JS()
@staticInterop
class JSReadResult {}

extension JSReadResultExtension on JSReadResult {
  external bool get done;

  external JSUint8Array? get value;
}
// ----------------------------------------------

class SerialWorker {
  JSSerialPort? _port;
  bool isConnected = false;
  String status = "未連線";
  VoidCallback? onStatusChange;
  final _receiveController = StreamController<String>.broadcast();

  Stream<String> get receiveStream => _receiveController.stream;

  void init() {}

  Future<void> connect() async {
    try {
      final port = await requestWebSerialPort(null);
      if (port != null) {
        _port = port;
        await _port!
            .open(
              JSSerialOptions(
                baudRate: 115200,
                dataBits: 8,
                stopBits: 1,
                parity: "none",
                bufferSize: 16384,
                flowControl: "none",
              ),
            )
            .toDart;

        isConnected = true;
        status = "Web 已連線";
        onStatusChange?.call();

        // 啟動監聽迴圈，接收來自 ESP32 的 Debug Log
        _readLoop();
      }
    } catch (e) {
      status = "連線失敗: $e";
      debugPrint("Serial Error: $e");
      onStatusChange?.call();
    }
  }

  Future<void> _readLoop() async {
    if (_port == null || _port!.readable == null) return;

    while (isConnected && _port != null) {
      // 將原始 JSObject 強制轉換為我們定義的擴充型別
      final reader =
          _port!.readable!.getReader() as JSReadableStreamDefaultReader;

      try {
        while (true) {
          final jsResult = await reader.read().toDart;
          final result = jsResult as JSReadResult;

          if (result.done) break;

          final uint8Array = result.value;
          if (uint8Array != null) {
            final data = uint8Array.toDart;
            String log = utf8.decode(data, allowMalformed: true);
            _receiveController.add(log);
            debugPrint("ESP32_LOG: $log");
          }
        }
      } catch (e) {
        debugPrint("Read Loop Error: $e");
        break;
      } finally {
        reader.releaseLock();
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> sendRawCommand(String command) async {
    if (!isConnected || _port?.writable == null) {
      debugPrint("WebSerial: Cannot send, port not writable.");
      return;
    }
    try {
      final writer = _port!.writable!.getWriter();
      final data = Uint8List.fromList(utf8.encode(command));
      await writer.write(data.toJS).toDart;
      writer.releaseLock();
    } catch (e) {
      debugPrint("WebSerial Send Error: $e");
    }
  }

  Future<void> sendLedImage(String text, LedSequence config) async {
    if (!isConnected) return;

    final result = await LedCommandHelper.generateCommand(
      text: text,
      config: config,
    );

    await sendRawCommand(result.command);
  }
}
