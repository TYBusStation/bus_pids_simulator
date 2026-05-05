import 'dart:async';

abstract class TTSInterface {
  Future<void> init();

  Future<void> stop();

  Future<void> speak(
    String text, {
    double pitch = 1.0,
    double rate = 1.0,
    double volume = 1.0,
    String? locale,
  });

  factory TTSInterface() => getTTS();
}

TTSInterface getTTS() => throw UnsupportedError('TTS not supported');
