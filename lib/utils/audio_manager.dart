import 'dart:async';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'static.dart';
import 'utils_helper.dart';

class VoicePack {
  final String name;
  final int timestamp;
  final List<String> fileNames;
  bool isEnabled;
  int priority;

  VoicePack({
    required this.name,
    required this.timestamp,
    required this.fileNames,
    this.isEnabled = true,
    this.priority = 0,
  });

  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

class AudioManager {
  static const String _boxName = "custom_audio_box";
  static const String _packMetaBoxName = "voice_packs_metadata";
  static const String _packDataBoxName = "voice_packs_data";

  late LazyBox<Uint8List> _audioBox;
  late Box<Map> _packMetaBox;
  late LazyBox<Uint8List> _packDataBox;

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  final List<VoicePack> voicePacks = [];

  Future<void> init() async {
    await Hive.initFlutter();
    _audioBox = await Hive.openLazyBox<Uint8List>(_boxName);
    _packMetaBox = await Hive.openBox<Map>(_packMetaBoxName);
    _packDataBox = await Hive.openLazyBox<Uint8List>(_packDataBoxName);
    await _loadStoredPacks();
  }

  Future<void> _loadStoredPacks() async {
    voicePacks.clear();
    final List<Map> metaList = _packMetaBox.values.cast<Map>().toList();
    metaList.sort((a, b) => (a['priority'] ?? 0).compareTo(b['priority'] ?? 0));

    for (var data in metaList) {
      voicePacks.add(
        VoicePack(
          name: data['name'],
          timestamp: data['timestamp'] ?? 0,
          fileNames: List<String>.from(data['fileNames'] ?? []),
          isEnabled: data['isEnabled'] ?? true,
          priority: data['priority'] ?? 0,
        ),
      );
    }
  }

  Future<void> reorderPack(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = voicePacks.removeAt(oldIndex);
    voicePacks.insert(newIndex, item);

    for (int i = 0; i < voicePacks.length; i++) {
      voicePacks[i].priority = i;
      final data = _packMetaBox.get(voicePacks[i].name);
      if (data != null) {
        data['priority'] = i;
        await _packMetaBox.put(voicePacks[i].name, data);
      }
    }
  }

  Future<bool> importZipAsPack(String name, Uint8List zipBytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      List<String> fileNames = [];
      for (final file in archive) {
        if (file.isFile) {
          final fileName = _stripExtension(file.name.split('/').last);
          if (fileName.isEmpty || fileName.startsWith('.')) continue;
          final content = Uint8List.fromList(file.content as List<int>);
          await _packDataBox.put("$name:$fileName", content);
          fileNames.add(fileName);
        }
      }
      if (fileNames.isEmpty) return false;

      await _packMetaBox.put(name, {
        'name': name,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'fileNames': fileNames,
        'isEnabled': true,
        'priority': voicePacks.length,
      });
      await _loadStoredPacks();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> togglePackStatus(int index, bool enabled) async {
    final pack = voicePacks[index];
    pack.isEnabled = enabled;
    final data = _packMetaBox.get(pack.name);
    if (data != null) {
      data['isEnabled'] = enabled;
      await _packMetaBox.put(pack.name, data);
    }
  }

  Future<bool> replacePack(int index, Uint8List zipBytes) async {
    final packName = voicePacks[index].name;
    final oldPriority = voicePacks[index].priority;
    await removePack(index);

    bool ok = await importZipAsPack(packName, zipBytes);
    if (ok) {
      final data = _packMetaBox.get(packName);
      if (data != null) {
        data['priority'] = oldPriority;
        await _packMetaBox.put(packName, data);
        await _loadStoredPacks();
      }
    }
    return ok;
  }

  Future<void> removePack(int index) async {
    final pack = voicePacks[index];
    for (var fileName in pack.fileNames) {
      await _packDataBox.delete("${pack.name}:$fileName");
    }
    await _packMetaBox.delete(pack.name);
    voicePacks.removeAt(index);
    for (int i = 0; i < voicePacks.length; i++) {
      final data = _packMetaBox.get(voicePacks[i].name);
      if (data != null) {
        data['priority'] = i;
        await _packMetaBox.put(voicePacks[i].name, data);
      }
    }
  }

  String _stripExtension(String name) {
    final lastDot = name.lastIndexOf('.');
    return (lastDot != -1) ? name.substring(0, lastDot) : name;
  }

  Future<Uint8List?> getPackBytes(String packName, String fileName) async {
    return await _packDataBox.get("$packName:$fileName");
  }

  Future<Uint8List?> _getRandomBytes(String baseName) async {
    List<String> audioBoxKeys = _audioBox.keys.cast<String>().toList();
    List<String> audioBoxMatches = audioBoxKeys
        .where((key) => key == baseName || key.startsWith("${baseName}_["))
        .toList();

    if (audioBoxMatches.isNotEmpty) {
      final selectedKey =
          audioBoxMatches[_random.nextInt(audioBoxMatches.length)];
      return await _audioBox.get(selectedKey);
    }

    for (var pack in voicePacks) {
      if (!pack.isEnabled) continue;

      List<String> packMatches = pack.fileNames
          .where((fn) => fn == baseName || fn.startsWith("${baseName}_["))
          .toList();

      if (packMatches.isNotEmpty) {
        final selectedFileName =
            packMatches[_random.nextInt(packMatches.length)];
        return await _packDataBox.get("${pack.name}:$selectedFileName");
      }
    }
    return null;
  }

  bool hasAudio(String name) {
    if (_audioBox.containsKey(name)) return true;
    if (_audioBox.keys.any((k) => k.toString().startsWith("${name}_[")))
      return true;

    for (var pack in voicePacks) {
      if (pack.isEnabled &&
          pack.fileNames.any((k) => k == name || k.startsWith("${name}_["))) {
        return true;
      }
    }
    return false;
  }

  Future<void> _applySettings(double localSpeed) async {
    await _player.setVolume(Static.globalVolume.clamp(0.0, 1.0));
    await _player.setPlaybackRate(
      (Static.globalSpeed * localSpeed).clamp(0.5, 2.0),
    );
  }

  Future<void> playAudio(String name, {double localSpeed = 1.0}) async {
    final bytes = await _getRandomBytes(name);
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
    final bytes = await _getRandomBytes(name);
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
      await completer.future;
    }
  }

  Future<void> playAssetAndWait(String path, {double localSpeed = 1.0}) async {
    try {
      await _player.stop();
      if (kIsWeb) await _player.release();
      await _player.setSource(AssetSource(path));
      await _player.setVolume(Static.globalVolume.clamp(0.0, 1.0));
      final completer = Completer<void>();
      StreamSubscription? sub;
      sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
        sub?.cancel();
      });
      await _player.resume();
      await _player.setPlaybackRate(
        (Static.globalSpeed * localSpeed).clamp(0.5, 2.0),
      );
      await completer.future;
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> stop() async => await _player.stop();

  List<String> get allAudioNames => _audioBox.keys.cast<String>().toList();

  Future<bool> saveAudio(String n, Uint8List b) async {
    try {
      await _audioBox.put(_stripExtension(n), b);
      return true;
    } catch (e) {
      return false;
    }
  }

  bool hasLocalAudio(String name) =>
      _audioBox.containsKey(_stripExtension(name));

  String generateUniqueName(String base) {
    String name = _stripExtension(base);
    if (_audioBox.containsKey(name)) {
      int i = 1;
      while (_audioBox.containsKey("${name}_[$i]")) i++;
      return "${name}_[$i]";
    }
    return name;
  }

  Future<void> renameAudio(String o, String n) async {
    final b = await _audioBox.get(o);
    if (b != null) {
      await _audioBox.put(n, b);
      await _audioBox.delete(o);
    }
  }

  Future<void> deleteAudio(String n) async => await _audioBox.delete(n);

  Future<void> exportSingle(String n) async {
    final b = await _audioBox.get(n);
    if (b != null) downloadFile(b, "$n.mp3");
  }

  Future<void> exportAllZip() async {
    final archive = Archive();
    final names = allAudioNames;
    if (names.isEmpty) return;
    for (var name in names) {
      final bytes = await _audioBox.get(name);
      if (bytes != null) {
        archive.addFile(ArchiveFile("$name.mp3", bytes.length, bytes));
      }
    }
    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      downloadFile(
        Uint8List.fromList(zipData),
        "backup_${DateTime.now().millisecondsSinceEpoch}.zip",
      );
    }
  }

  Future<PlatformFile?> pickSingleFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result != null) return result.files.first;
    return null;
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
