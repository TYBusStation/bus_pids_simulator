import 'dart:async';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'static.dart';
import 'utils.dart'
    if (dart.library.js_interop) 'utils_web.dart'
    if (dart.library.io) 'utils_stub.dart';

class AudioManager {
  static const String _boxName = "custom_audio_box";
  late Box<Uint8List> _audioBox;
  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  final Map<String, Uint8List> _memoryCache = {};

  Future<void> init() async {
    await Hive.initFlutter();
    _audioBox = await Hive.openBox<Uint8List>(_boxName);
  }

  List<String> get allAudioNames => _audioBox.keys.cast<String>().toList();

  String _stripExtension(String name) {
    final lastDot = name.lastIndexOf('.');
    return (lastDot != -1) ? name.substring(0, lastDot) : name;
  }

  String _getAvailableName(String baseName) {
    String cleanName = _stripExtension(baseName);
    if (!_audioBox.containsKey(cleanName)) return cleanName;
    int counter = 1;
    while (true) {
      final newName = "${cleanName}_[$counter]";
      if (!_audioBox.containsKey(newName)) return newName;
      counter++;
    }
  }

  String _getRandomAudioKey(String baseName) {
    final keys = _audioBox.keys.cast<String>().where((k) {
      return k == baseName || k.startsWith("${baseName}_[");
    }).toList();
    if (keys.isEmpty) return baseName;
    return keys[_random.nextInt(keys.length)];
  }

  Uint8List? _getBytes(String key) {
    if (_memoryCache.containsKey(key)) return _memoryCache[key];
    final bytes = _audioBox.get(key);
    if (bytes != null && _memoryCache.length < 50) {
      _memoryCache[key] = bytes;
    }
    return bytes;
  }

  Future<void> saveAudio(String name, Uint8List bytes) async {
    final finalName = _getAvailableName(name);
    await _audioBox.put(finalName, bytes);
    _memoryCache[finalName] = bytes;
  }

  Future<void> renameAudio(String oldName, String newName) async {
    if (oldName == newName) return;
    final bytes = _audioBox.get(oldName);
    if (bytes != null) {
      final finalName = _getAvailableName(newName);
      await _audioBox.put(finalName, bytes);
      await _audioBox.delete(oldName);
      _memoryCache.remove(oldName);
      _memoryCache[finalName] = bytes;
    }
  }

  Future<void> deleteAudio(String name) async {
    await _audioBox.delete(name);
    _memoryCache.remove(name);
  }

  bool hasAudio(String name) {
    return _audioBox.keys.cast<String>().any(
      (k) => k == name || k.startsWith("${name}_["),
    );
  }

  Future<void> _applySettings(double localSpeed) async {
    await _player.setVolume(Static.globalVolume.clamp(0.0, 1.0));
    await _player.setPlaybackRate(
      (Static.globalSpeed * localSpeed).clamp(0.5, 2.0),
    );
  }

  Future<void> playAudio(String name, {double localSpeed = 1.0}) async {
    final key = _getRandomAudioKey(name);
    final bytes = _getBytes(key);
    if (bytes != null) {
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.stop();
      await _player.setSource(BytesSource(bytes));
      await _applySettings(localSpeed);
      await _player.resume();
    }
  }

  Future<void> playAndWait(String name, {double localSpeed = 1.0}) async {
    final key = _getRandomAudioKey(name);
    final bytes = _getBytes(key);
    if (bytes != null) {
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await _player.setSource(BytesSource(bytes));
      await _applySettings(localSpeed);
      final completer = Completer<void>();
      StreamSubscription? sub;
      sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
        sub?.cancel();
      });
      await _player.resume();
      if (kIsWeb) {
        await _player.setPlaybackRate(
          (Static.globalSpeed * localSpeed).clamp(0.5, 2.0),
        );
      }
      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => sub?.cancel(),
      );
    }
  }

  Future<void> playAssetAndWait(String path, {double localSpeed = 1.0}) async {
    await _player.setReleaseMode(ReleaseMode.release);
    await _player.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await _player.setSource(AssetSource(path));
    await _applySettings(localSpeed);
    final completer = Completer<void>();
    StreamSubscription? sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      sub?.cancel();
    });
    await _player.resume();
    if (kIsWeb) {
      await _player.setPlaybackRate(
        (Static.globalSpeed * localSpeed).clamp(0.5, 2.0),
      );
    }
    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => sub?.cancel(),
    );
  }

  Future<void> startAssetLoop(String path) async {
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setSource(AssetSource(path));
    await _applySettings(1.0);
    await _player.resume();
    if (kIsWeb) {
      await _player.setPlaybackRate(Static.globalSpeed.clamp(0.5, 2.0));
    }
  }

  Future<void> stop() async {
    await _player.setReleaseMode(ReleaseMode.release);
    await _player.stop();
  }

  Future<void> pickAndSave(String name) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result != null && result.files.first.bytes != null) {
      await saveAudio(name, result.files.first.bytes!);
    }
  }

  void exportSingle(String name) {
    final bytes = _audioBox.get(name);
    if (bytes != null) downloadFile(bytes, "$name.mp3");
  }

  void exportAllZip() {
    final archive = Archive();
    for (var name in allAudioNames) {
      final bytes = _audioBox.get(name);
      if (bytes != null) {
        archive.addFile(ArchiveFile("$name.mp3", bytes.length, bytes));
      }
    }
    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      downloadFile(Uint8List.fromList(zipData), "bus_audio_backup.zip");
    }
  }

  Future<Map<String, Uint8List>?> pickZipFiles() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || result.files.first.bytes == null) return null;
    final Map<String, Uint8List> extracted = {};
    final archive = ZipDecoder().decodeBytes(result.files.first.bytes!);
    for (final file in archive) {
      if (file.isFile) {
        final fileName = file.name.split('/').last.split('\\').last;
        if (fileName.isEmpty || fileName.startsWith('.')) continue;
        extracted[_stripExtension(fileName)] = Uint8List.fromList(
          file.content as List<int>,
        );
      }
    }
    return extracted;
  }
}
