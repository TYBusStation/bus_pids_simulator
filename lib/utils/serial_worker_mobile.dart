import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';

import '../data/led_sequence.dart';
import 'led_command_helper.dart';

class SerialWorker {
  dynamic _port;
  bool isConnected = false;
  String status = "未連線";
  VoidCallback? onStatusChange;

  final _receiveController = StreamController<String>.broadcast();

  Stream<String> get receiveStream => _receiveController.stream;

  void init() {
    UsbSerial.usbEventStream?.listen((event) {
      debugPrint("USB Event: ${event.event}");
      if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        isConnected = false;
        status = "裝置已拔除";
        _port = null;
        onStatusChange?.call();
      } else if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        debugPrint("偵測到裝置插入，嘗試連線...");
        connect();
      }
    });
    connect();
  }

  Future<void> connect() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();
      debugPrint("找到裝置數量: ${devices.length}");

      if (devices.isEmpty) {
        status = "未發現裝置";
        isConnected = false;
        onStatusChange?.call();
        return;
      }

      UsbDevice device = devices.first;

      _port = await device.create();

      bool openResult = await _port.open();
      if (!openResult) {
        status = "無法開啟序列埠";
        onStatusChange?.call();
        return;
      }

      await _port.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      await _port.setDTR(true);
      await _port.setRTS(true);

      _port.inputStream.listen((Uint8List data) {
        String log = utf8.decode(data, allowMalformed: true);
        _receiveController.add(log);
        debugPrint("ESP32_LOG: $log");
      });

      isConnected = true;
      status = "Android 已連線";
      onStatusChange?.call();
    } catch (e) {
      debugPrint("連線錯誤: $e");
      status = "連線失敗";
      isConnected = false;
      onStatusChange?.call();
    }
  }

  Future<void> sendRawCommand(String command) async {
    if (!isConnected || _port == null) {
      debugPrint("UsbSerial: Cannot send, port is null.");
      return;
    }
    try {
      final data = Uint8List.fromList(utf8.encode(command));
      _port.write(data);
    } catch (e) {
      debugPrint("UsbSerial Send Error: $e");
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
