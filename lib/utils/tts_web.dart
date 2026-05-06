import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'tts.dart';

class TTSWeb implements TTSInterface {
  web.SpeechSynthesisVoice? _bestZhVoice;
  web.SpeechSynthesisVoice? _bestEnVoice;

  @override
  Future<void> init() async {
    _loadVoices();
    web.window.speechSynthesis.onvoiceschanged = (web.Event _) {
      _loadVoices();
    }.toJS;
  }

  void _loadVoices() {
    final voices = web.window.speechSynthesis.getVoices();
    if (voices.length == 0) return;

    List<web.SpeechSynthesisVoice> zhCandidates = [];
    List<web.SpeechSynthesisVoice> enCandidates = [];

    for (int i = 0; i < voices.length; i++) {
      final v = voices[i];
      final lang = v.lang.toLowerCase();
      if (lang.contains('zh-tw') ||
          lang.contains('zh_tw') ||
          lang.contains('cmn-hant-tw')) {
        zhCandidates.add(v);
      } else if (lang.startsWith('en')) {
        enCandidates.add(v);
      }
    }

    _bestZhVoice = _findVoice(zhCandidates, [
      'online',
      'neural',
      'premium',
      'google',
      'microsoft',
    ]);
    _bestEnVoice = _findVoice(enCandidates, [
      'google',
      'online',
      'neural',
      'zira',
      'female',
      'apple',
    ]);
  }

  web.SpeechSynthesisVoice? _findVoice(
    List<web.SpeechSynthesisVoice> list,
    List<String> priority,
  ) {
    if (list.isEmpty) return null;
    for (var p in priority) {
      try {
        return list.firstWhere((v) => v.name.toLowerCase().contains(p));
      } catch (_) {}
    }
    return list.first;
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
    String? locale,
  }) async {
    web.window.speechSynthesis.cancel();
    web.window.speechSynthesis.resume();

    await Future.delayed(const Duration(milliseconds: 100));

    final completer = Completer<void>();
    final utterance = web.SpeechSynthesisUtterance(text);

    if (locale != null && locale.startsWith("en")) {
      utterance.lang = 'en-US';
      if (_bestEnVoice != null) utterance.voice = _bestEnVoice;
    } else {
      utterance.lang = 'zh-TW';
      if (_bestZhVoice != null) utterance.voice = _bestZhVoice;
    }

    utterance.pitch = pitch;
    utterance.rate = (rate * 0.9).clamp(0.1, 10.0);
    utterance.volume = volume;

    utterance.onend = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    utterance.onerror = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    web.window.speechSynthesis.speak(utterance);

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      },
    );
  }
}

TTSInterface getTTS() => TTSWeb();
