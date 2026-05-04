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

  void _loadBestVoice() {
    final voices = web.window.speechSynthesis.getVoices();
    if (voices.length == 0) return;

    List<web.SpeechSynthesisVoice> candidates = [];
    for (int i = 0; i < voices.length; i++) {
      final v = voices[i];
      final lang = v.lang.toLowerCase();
      // 擴張匹配三星與 Android 可能出現的標籤
      if (lang.contains('zh-tw') ||
          lang.contains('zh_tw') ||
          lang.contains('cmn-hant-tw')) {
        candidates.add(v);
      }
    }

    if (candidates.isEmpty) {
      for (int i = 0; i < voices.length; i++) {
        if (voices[i].lang.toLowerCase().contains('zh'))
          candidates.add(voices[i]);
      }
    }

    if (candidates.isEmpty) return;

    try {
      // 優先尋找高品質語音
      _bestVoice = candidates.firstWhere(
        (v) =>
            v.name.contains('Online') ||
            v.name.contains('Neural') ||
            v.name.contains('Premium'),
      );
    } catch (_) {
      try {
        _bestVoice = candidates.firstWhere(
          (v) => v.name.contains('Google') || v.name.contains('Samsung'),
        );
      } catch (_) {
        _bestVoice = candidates.first;
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
    // 強制喚醒引擎
    web.window.speechSynthesis.cancel();
    web.window.speechSynthesis.resume();

    // 如果目前沒語音庫，嘗試再抓一次（解決三星/Chrome 延遲載入問題）
    if (_bestVoice == null) _loadBestVoice();

    final completer = Completer<void>();
    _currentUtterance = web.SpeechSynthesisUtterance(text);

    if (_bestVoice != null) {
      _currentUtterance!.voice = _bestVoice;
    }

    // 設定語系，即使沒選到 voice，瀏覽器也會用該語系的預設值
    _currentUtterance!.lang = 'zh-TW';
    _currentUtterance!.pitch = pitch;
    _currentUtterance!.rate = (rate * 0.9).clamp(0.5, 2.0);
    _currentUtterance!.volume = volume;

    _currentUtterance!.onend = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    _currentUtterance!.onerror = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    web.window.speechSynthesis.speak(_currentUtterance!);

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      },
    );
  }
}

TTSInterface getTTS() => TTSWeb();
