import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts.dart';

class TTSStub implements TTSInterface {
  final FlutterTts _tts = FlutterTts();
  Completer<void>? _speechCompleter;

  @override
  Future<void> init() async {
    await _tts.setLanguage("zh-TW");
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      _completeSpeech();
    });

    _tts.setErrorHandler((msg) {
      _completeSpeech();
    });

    _tts.setCancelHandler(() {
      _completeSpeech();
    });
  }

  void _completeSpeech() {
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _completeSpeech();
  }

  @override
  Future<void> speak(
    String text, {
    double pitch = 1.0,
    double rate = 1.0,
    double volume = 1.0,
  }) async {
    _completeSpeech();

    _speechCompleter = Completer<void>();

    await _tts.setPitch(pitch * 2.5 - 1.5);
    await _tts.setSpeechRate(rate * 1.2 - 0.8);
    await _tts.setVolume(volume);

    await _tts.speak(text);

    return _speechCompleter!.future;
  }
}

TTSInterface getTTS() => TTSStub();
