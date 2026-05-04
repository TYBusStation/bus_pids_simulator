import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'tts.dart';

class TTSWeb implements TTSInterface {
  web.SpeechSynthesisVoice? _bestVoice;

  web.SpeechSynthesisUtterance? _currentUtterance;

  @override
  Future<void> init() async {
    _loadBestVoice();
    web.window.speechSynthesis.onvoiceschanged = (web.Event _) {
      _loadBestVoice();
    }.toJS;
  }

  Future<void> _loadBestVoice() async {
    final voices = web.window.speechSynthesis.getVoices();
    if (voices.length == 0) return;

    List<web.SpeechSynthesisVoice> zhVoices = [];
    for (int i = 0; i < voices.length; i++) {
      final v = voices[i];
      if (v.lang.contains('zh-TW') || v.lang.contains('zh_TW')) {
        zhVoices.add(v);
      }
    }

    if (zhVoices.isEmpty) {
      for (int i = 0; i < voices.length; i++) {
        if (voices[i].lang.contains('zh')) {
          zhVoices.add(voices[i]);
        }
      }
    }

    if (zhVoices.isEmpty) return;

    try {
      _bestVoice = zhVoices.firstWhere(
        (v) =>
            (v.name.contains('Online') || v.name.contains('Neural')) &&
            v.lang.contains('zh-TW'),
      );
    } catch (_) {
      try {
        _bestVoice = zhVoices.firstWhere((v) => v.name.contains('Google'));
      } catch (_) {
        _bestVoice = zhVoices.first;
      }
    }
  }

  @override
  Future<void> stop() async {
    web.window.speechSynthesis.cancel();
  }

  @override
  Future<void> speak(
    String text, {
    double pitch = 1.0,
    double rate = 1.0,
    double volume = 1.0,
  }) async {
    web.window.speechSynthesis.resume();

    if (_bestVoice == null) await _loadBestVoice();

    web.window.speechSynthesis.cancel();
    await Future.delayed(const Duration(milliseconds: 50));

    final completer = Completer<void>();

    _currentUtterance = web.SpeechSynthesisUtterance(text);

    if (_bestVoice != null) {
      _currentUtterance!.voice = _bestVoice;
    }
    _currentUtterance!.lang = 'zh-TW';
    _currentUtterance!.pitch = pitch;
    _currentUtterance!.rate = (rate * 0.9).clamp(0.1, 2.0);
    _currentUtterance!.volume = volume;

    _currentUtterance!.onend = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    _currentUtterance!.onerror = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    web.window.speechSynthesis.speak(_currentUtterance!);

    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      },
    );
  }
}

TTSInterface getTTS() => TTSWeb();
