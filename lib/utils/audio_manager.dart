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

class VoicePack {
  final String name;
  final int timestamp;
  final Map<String, Uint8List> files;

  VoicePack({required this.name, required this.timestamp, required this.files});
}

class AudioManager {
  static const String _boxName = "custom_audio_box";
  static const String _packBoxName = "voice_packs_data";

  late Box<Uint8List> _audioBox;
  late Box<Map> _packBox;

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  final List<VoicePack> voicePacks = [];

  Future<void> init() async {
    await Hive.initFlutter();
    _audioBox = await Hive.openBox<Uint8List>(_boxName);
    _packBox = await Hive.openBox<Map>(_packBoxName);
    await _loadStoredPacks();
  }

  Future<void> _loadStoredPacks() async {
    voicePacks.clear();
    for (var key in _packBox.keys) {
      final data = _packBox.get(key);
      if (data != null) {
        Map<String, Uint8List> extractedFiles = {};
        if (data['files'] is Map) {
          (data['files'] as Map).forEach((k, v) {
            extractedFiles[k.toString()] = v as Uint8List;
          });
        }
        voicePacks.add(
          VoicePack(
            name: data['name'] ?? key.toString(),
            timestamp: data['timestamp'] ?? 0,
            files: extractedFiles,
          ),
        );
      }
    }
  }

  Future<bool> importZipAsPack(String name, Uint8List zipBytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      Map<String, Uint8List> extracted = {};
      for (final file in archive) {
        if (file.isFile) {
          final fileName = _stripExtension(file.name.split('/').last);
          if (fileName.isEmpty || fileName.startsWith('.')) continue;
          extracted[fileName] = Uint8List.fromList(file.content as List<int>);
        }
      }

      if (extracted.isEmpty) return false;

      await _packBox.put(name, {
        'name': name,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'files': extracted,
      });

      await _loadStoredPacks();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> replacePack(int index, Uint8List zipBytes) async {
    final packName = voicePacks[index].name;
    return await importZipAsPack(packName, zipBytes);
  }

  Future<void> removePack(int index) async {
    final packName = voicePacks[index].name;
    await _packBox.delete(packName);
    voicePacks.removeAt(index);
  }

  String _stripExtension(String name) {
    final lastDot = name.lastIndexOf('.');
    return (lastDot != -1) ? name.substring(0, lastDot) : name;
  }

  Uint8List? _getRandomBytes(String baseName) {
    List<Uint8List> candidates = [];

    for (var key in _audioBox.keys.cast<String>()) {
      if (key == baseName || key.startsWith("${baseName}_[")) {
        final b = _audioBox.get(key);
        if (b != null) candidates.add(b);
      }
    }

    for (var pack in voicePacks) {
      if (pack.files.containsKey(baseName)) {
        candidates.add(pack.files[baseName]!);
      }
      pack.files.forEach((key, value) {
        if (key.startsWith("${baseName}_[")) {
          candidates.add(value);
        }
      });
    }

    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  bool hasAudio(String name) {
    bool localExists = _audioBox.keys.cast<String>().any(
      (k) => k == name || k.startsWith("${name}_["),
    );
    bool packExists = voicePacks.any(
      (p) =>
          p.files.containsKey(name) ||
          p.files.keys.any((k) => k.startsWith("${name}_[")),
    );
    return localExists || packExists;
  }

  Future<void> _applySettings(double localSpeed) async {
    await _player.setVolume(Static.globalVolume.clamp(0.0, 1.0));
    await _player.setPlaybackRate(
      (Static.globalSpeed * localSpeed).clamp(0.5, 2.0),
    );
  }

  Future<void> playAudio(String name, {double localSpeed = 1.0}) async {
    final bytes = _getRandomBytes(name);
    if (bytes != null) {
      await _player.stop();
      await _player.setSource(BytesSource(bytes));
      await _applySettings(localSpeed);
      await _player.resume();
    }
  }

  Future<void> playRawBytes(Uint8List bytes) async {
    await _player.stop();
    await _player.setSource(BytesSource(bytes));
    await _player.setVolume(Static.globalVolume.clamp(0.0, 1.0));
    await _player.setPlaybackRate(Static.globalSpeed.clamp(0.5, 2.0));
    await _player.resume();
  }

  Future<void> playAndWait(String name, {double localSpeed = 1.0}) async {
    final bytes = _getRandomBytes(name);
    if (bytes != null) {
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
      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => sub?.cancel(),
      );
    }
  }

  Future<void> playAssetAndWait(String path, {double localSpeed = 1.0}) async {
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
    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => sub?.cancel(),
    );
  }

  Future<void> stop() async => await _player.stop();

  List<String> get allAudioNames => _audioBox.keys.cast<String>().toList();

  Future<void> saveAudio(String n, Uint8List b) async =>
      await _audioBox.put(_stripExtension(n), b);

  Future<void> renameAudio(String o, String n) async {
    final b = _audioBox.get(o);
    if (b != null) {
      await _audioBox.put(n, b);
      await _audioBox.delete(o);
    }
  }

  Future<void> deleteAudio(String n) async => await _audioBox.delete(n);

  void exportSingle(String n) {
    final b = _audioBox.get(n);
    if (b != null) downloadFile(b, "$n.mp3");
  }

  void exportAllZip() {
    final archive = Archive();
    for (var name in allAudioNames) {
      final bytes = _audioBox.get(name);
      if (bytes != null)
        archive.addFile(ArchiveFile("$name.mp3", bytes.length, bytes));
    }
    final zipData = ZipEncoder().encode(archive);
    if (zipData != null)
      downloadFile(Uint8List.fromList(zipData), "bus_audio_backup.zip");
  }

  Future<void> pickAndSave(String name) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result != null && result.files.first.bytes != null)
      await saveAudio(name, result.files.first.bytes!);
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
        final fileName = _stripExtension(file.name.split('/').last);
        extracted[fileName] = Uint8List.fromList(file.content as List<int>);
      }
    }
    return extracted;
  }
}
