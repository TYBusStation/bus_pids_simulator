import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'tts.dart';

class TTSWeb implements TTSInterface {
  web.SpeechSynthesisVoice? _bestVoice;

  @override
  Future<void> init() async {
    await _loadBestVoice();
    web.window.speechSynthesis.onvoiceschanged = (web.Event _) {
      _loadBestVoice();
    }.toJS;
  }

  Future<void> _loadBestVoice() async {
    final voices = web.window.speechSynthesis.getVoices();
    List<web.SpeechSynthesisVoice> zhVoices = [];

    for (int i = 0; i < voices.length; i++) {
      final v = voices[i];
      if (v.lang.contains('zh-TW') || v.lang.contains('zh_TW')) {
        zhVoices.add(v);
      }
    }

    if (zhVoices.isEmpty) return;

    // 優先順序：Microsoft Online (Neural) > Google 國語 > 其他
    try {
      _bestVoice = zhVoices.firstWhere(
        (v) => v.name.contains('Online') || v.name.contains('Neural'),
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
    if (_bestVoice == null) await _loadBestVoice();

    final completer = Completer<void>();
    final utterance = web.SpeechSynthesisUtterance(text);

    if (_bestVoice != null) {
      utterance.voice = _bestVoice;
    }

    utterance.pitch = pitch;
    utterance.rate = rate * 0.9; // 略微放慢語速通常聽起來較自然
    utterance.lang = 'zh-TW';
    utterance.volume = volume;

    utterance.onend = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    utterance.onerror = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    web.window.speechSynthesis.speak(utterance);
    return completer.future;
  }
}

TTSInterface getTTS() => TTSWeb();
