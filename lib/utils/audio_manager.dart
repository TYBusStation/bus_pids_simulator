import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

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
  late Box _packMetaBox;
  late LazyBox<Uint8List> _packDataBox;

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  final List<VoicePack> voicePacks = [];

  final Map<String, Uint8List> _memoryCache = {};
  final Set<String> _currentRouteKeys = {};
  static const int _maxCacheEntries = 100;

  Future<void> init() async {
    await Hive.initFlutter();
    _audioBox = await Hive.openLazyBox<Uint8List>(_boxName);
    _packMetaBox = await Hive.openBox(_packMetaBoxName);
    _packDataBox = await Hive.openLazyBox<Uint8List>(_packDataBoxName);
    await _loadStoredPacks();
    await preloadCommonAudios();
  }

  String _sanitizeKey(String name) {
    return name
        .replaceAll(RegExp(r'[\\/*?:"<>|]'), '')
        .replaceAll(RegExp(r'\.+$'), '')
        .trim();
  }

  Future<Uint8List?> _searchInBox(LazyBox<Uint8List> box, String key) async {
    if (box.containsKey(key)) {
      return await box.get(key);
    }
    final keys = box.keys.cast<String>();
    final matches = keys.where((k) => k.startsWith("${key}_[")).toList();
    if (matches.isNotEmpty) {
      return await box.get(matches[_random.nextInt(matches.length)]);
    }
    return null;
  }

  Future<Uint8List?> _searchInPacks(String key) async {
    for (var pack in voicePacks) {
      if (!pack.isEnabled) continue;

      if (pack.fileNames.contains(key)) {
        return await _packDataBox.get("${pack.name}:$key");
      }
      final matches = pack.fileNames
          .where((fn) => fn.startsWith("${key}_["))
          .toList();
      if (matches.isNotEmpty) {
        return await _packDataBox.get(
          "${pack.name}:${matches[_random.nextInt(matches.length)]}",
        );
      }
    }
    return null;
  }

  Future<Uint8List?> _getFinalAudioBytes(
    String name, {
    String? zhFallbackForEn,
  }) async {
    final String original = _sanitizeKey(name);
    final String lower = original.toLowerCase();

    Uint8List? b = await _searchInBox(_audioBox, original);
    if (b != null) return b;

    if (original != lower) {
      b = await _searchInBox(_audioBox, lower);
      if (b != null) return b;
    }

    b = await _searchInPacks(original);
    if (b != null) return b;

    if (original != lower) {
      b = await _searchInPacks(lower);
      if (b != null) return b;
    }

    if (zhFallbackForEn != null) {
      final String zhEnKey = "${_sanitizeKey(zhFallbackForEn)}_英";
      b = await _searchInBox(_audioBox, zhEnKey);
      if (b != null) return b;

      b = await _searchInPacks(zhEnKey);
      if (b != null) return b;
    }

    return null;
  }

  bool hasAudio(String name, {String? zhFallbackForEn}) {
    final String original = _sanitizeKey(name);
    final String lower = original.toLowerCase();

    bool check(String key) {
      if (_audioBox.containsKey(key)) return true;
      if (_audioBox.keys.any((k) => k.toString().startsWith("${key}_[")))
        return true;
      for (var pack in voicePacks) {
        if (pack.isEnabled &&
            (pack.fileNames.contains(key) ||
                pack.fileNames.any((fn) => fn.startsWith("${key}_["))))
          return true;
      }
      return false;
    }

    if (check(original)) return true;
    if (original != lower && check(lower)) return true;

    if (zhFallbackForEn != null) {
      if (check("${_sanitizeKey(zhFallbackForEn)}_英")) return true;
    }

    return false;
  }

  Future<void> playAndWait(
    String name, {
    double localSpeed = 1.0,
    String? zhFallbackForEn,
  }) async {
    final bytes = await _getFinalAudioBytes(
      name,
      zhFallbackForEn: zhFallbackForEn,
    );
    if (bytes != null) {
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 50));
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

  Future<void> preloadCommonAudios() async {
    final List<String> templates = [];
    templates.addAll(Static.settings.arrivalTemplate);
    templates.addAll(Static.settings.nextStationTemplate);
    templates.addAll(Static.settings.stationVoiceSequence);
    templates.addAll(Static.settings.nextStationListSequence);
    templates.addAll(Static.settings.nextStationSubSequence);

    for (var item in templates) {
      if (!item.contains("{") && !item.contains("}")) {
        await _ensureInCache(_sanitizeKey(item));
      }
    }
  }

  Future<void> preloadRouteStations(
    List<String> names, {
    List<String>? enNames,
  }) async {
    for (var key in _currentRouteKeys) {
      _memoryCache.remove(key);
    }
    _currentRouteKeys.clear();

    for (var name in names) {
      final cleanName = _sanitizeKey(name);
      final variants = [
        cleanName,
        "${cleanName}_國",
        "${cleanName}_英",
        "${cleanName}_閩",
        "${cleanName}_客",
      ];
      for (var v in variants) {
        if (await _ensureInCache(v)) {
          _currentRouteKeys.add(v);
        }
      }
    }

    if (enNames != null) {
      for (var enName in enNames) {
        if (enName.isNotEmpty) {
          final cleanEn = _sanitizeKey(enName);
          if (await _ensureInCache(cleanEn)) {
            _currentRouteKeys.add(cleanEn);
          }
        }
      }
    }
  }

  Future<bool> _ensureInCache(String key) async {
    if (_memoryCache.containsKey(key)) return true;

    if (_memoryCache.length > _maxCacheEntries) {
      final keysToRemove = _memoryCache.keys
          .where((k) => !_currentRouteKeys.contains(k))
          .toList();
      for (var k in keysToRemove) {
        _memoryCache.remove(k);
      }
      if (_memoryCache.length > _maxCacheEntries) _memoryCache.clear();
    }

    final bytes = await _findBytesInStorage(key);
    if (bytes != null) {
      _memoryCache[key] = bytes;
      return true;
    }
    return false;
  }

  Future<Uint8List?> _findBytesInStorage(String baseName) async {
    final searchKeys = [baseName, baseName.toLowerCase()].toSet().toList();

    for (var key in searchKeys) {
      if (_audioBox.containsKey(key)) {
        return await _audioBox.get(key);
      }

      final audioBoxKeys = _audioBox.keys.cast<String>();
      final audioBoxMatch = audioBoxKeys.firstWhere(
        (k) => k.startsWith("${key}_["),
        orElse: () => "",
      );
      if (audioBoxMatch.isNotEmpty) {
        return await _audioBox.get(audioBoxMatch);
      }

      for (var pack in voicePacks) {
        if (!pack.isEnabled) continue;

        if (pack.fileNames.contains(key)) {
          return await _packDataBox.get("${pack.name}:$key");
        }

        final packMatch = pack.fileNames.firstWhere(
          (fn) => fn.startsWith("${key}_["),
          orElse: () => "",
        );
        if (packMatch.isNotEmpty) {
          return await _packDataBox.get("${pack.name}:$packMatch");
        }
      }
    }

    return null;
  }

  Map? _getSafeMeta(String name) {
    final raw = _packMetaBox.get(name);
    if (raw == null) return null;
    if (raw is Map) return Map.from(raw);
    try {
      if (raw is Uint8List) {
        final decoded = jsonDecode(utf8.decode(raw));
        if (decoded is Map) return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadStoredPacks() async {
    voicePacks.clear();
    final List<VoicePack> loaded = [];
    for (var key in _packMetaBox.keys) {
      final data = _getSafeMeta(key.toString());
      if (data != null) {
        loaded.add(
          VoicePack(
            name: data['name']?.toString() ?? key.toString(),
            timestamp: data['timestamp'] ?? 0,
            fileNames: List<String>.from(data['fileNames'] ?? []),
            isEnabled: data['isEnabled'] ?? true,
            priority: data['priority'] ?? 0,
          ),
        );
      }
    }
    loaded.sort((a, b) => a.priority.compareTo(b.priority));
    voicePacks.addAll(loaded);
  }

  Future<void> reorderPack(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = voicePacks.removeAt(oldIndex);
    voicePacks.insert(newIndex, item);

    for (int i = 0; i < voicePacks.length; i++) {
      voicePacks[i].priority = i;
      final data = _getSafeMeta(voicePacks[i].name);
      if (data != null) {
        final Map<String, dynamic> updated = Map<String, dynamic>.from(data);
        updated['priority'] = i;
        await _packMetaBox.put(voicePacks[i].name, updated);
      }
    }
  }

  Future<bool> importZipAsPack(String name, Uint8List zipBytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      List<String> fileNames = [];
      for (final file in archive) {
        if (file.isFile) {
          final fileName = _sanitizeKey(file.name.split('/').last);
          if (fileName.isEmpty || fileName.startsWith('.')) continue;
          final content = Uint8List.fromList(file.content as List<int>);
          await _packDataBox.put("$name:$fileName", content);
          fileNames.add(fileName);
        }
      }
      if (fileNames.isEmpty) return false;

      final meta = {
        'name': name,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'fileNames': fileNames,
        'isEnabled': true,
        'priority': voicePacks.length,
      };
      await _packMetaBox.put(name, meta);
      await _loadStoredPacks();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> togglePackStatus(int index, bool enabled) async {
    final pack = voicePacks[index];
    pack.isEnabled = enabled;
    final data = _getSafeMeta(pack.name);
    if (data != null) {
      final Map<String, dynamic> updated = Map<String, dynamic>.from(data);
      updated['isEnabled'] = enabled;
      await _packMetaBox.put(pack.name, updated);
    }
  }

  Future<bool> replacePack(int index, Uint8List zipBytes) async {
    final packName = voicePacks[index].name;
    final oldPriority = voicePacks[index].priority;
    await removePack(index);

    bool ok = await importZipAsPack(packName, zipBytes);
    if (ok) {
      final data = _getSafeMeta(packName);
      if (data != null) {
        final Map<String, dynamic> updated = Map<String, dynamic>.from(data);
        updated['priority'] = oldPriority;
        await _packMetaBox.put(packName, updated);
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
      final data = _getSafeMeta(voicePacks[i].name);
      if (data != null) {
        final Map<String, dynamic> updated = Map<String, dynamic>.from(data);
        updated['priority'] = i;
        await _packMetaBox.put(voicePacks[i].name, updated);
      }
    }
  }

  Future<Uint8List?> getPackBytes(String packName, String fileName) async {
    return await _packDataBox.get("$packName:$fileName");
  }

  Future<Uint8List?> _getRandomBytes(String baseName) async {
    final lowerBase = baseName.toLowerCase();

    // --- 1. 從記憶體快取搜尋 ---
    List<String> cacheMatches = _memoryCache.keys
        .where(
          (key) =>
              key == baseName ||
              key == lowerBase ||
              key.startsWith("${baseName}_[") ||
              key.startsWith("${lowerBase}_["),
        )
        .toList();

    if (cacheMatches.isNotEmpty) {
      return _memoryCache[cacheMatches[_random.nextInt(cacheMatches.length)]];
    }

    // --- 2. 從本機資料庫 (_audioBox) 搜尋 ---
    List<String> audioBoxKeys = _audioBox.keys.cast<String>().toList();
    List<String> audioBoxMatches = audioBoxKeys
        .where(
          (key) =>
              key == baseName ||
              key == lowerBase ||
              key.startsWith("${baseName}_[") ||
              key.startsWith("${lowerBase}_["),
        )
        .toList();

    if (audioBoxMatches.isNotEmpty) {
      final selectedKey =
          audioBoxMatches[_random.nextInt(audioBoxMatches.length)];
      final b = await _audioBox.get(selectedKey);
      if (b != null) {
        await _ensureInCache(selectedKey);
        return b;
      }
    }

    // --- 3. 從語音包 (Voice Packs) 搜尋 ---
    for (var pack in voicePacks) {
      if (!pack.isEnabled) continue;
      List<String> packMatches = pack.fileNames
          .where(
            (fn) =>
                fn == baseName ||
                fn == lowerBase ||
                fn.startsWith("${baseName}_[") ||
                fn.startsWith("${lowerBase}_["),
          )
          .toList();

      if (packMatches.isNotEmpty) {
        final selectedFileName =
            packMatches[_random.nextInt(packMatches.length)];
        final cacheKey = "${pack.name}:$selectedFileName";
        final b = await _packDataBox.get(cacheKey);
        if (b != null) {
          // 存入快取時使用「封裝鍵值」
          _memoryCache[cacheKey] = b;
          return b;
        }
      }
    }
    return null;
  }

  Future<void> _applySettings(double localSpeed) async {
    await _player.setVolume(Static.settings.globalVolume.clamp(0.0, 1.0));
    await _player.setPlaybackRate(
      (Static.settings.globalSpeed * localSpeed).clamp(0.5, 2.0),
    );
  }

  Future<void> playAudio(String name, {double localSpeed = 1.0}) async {
    final bytes = await _getRandomBytes(_sanitizeKey(name));
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
    await _player.setVolume(Static.settings.globalVolume.clamp(0.0, 1.0));
    await _player.setPlaybackRate(Static.settings.globalSpeed.clamp(0.5, 2.0));
    await _player.resume();
  }

  Completer<void>? _currentCompleter;

  Future<void> playAssetAndWait(String path, {double localSpeed = 1.0}) async {
    await stop();
    _currentCompleter = Completer<void>();
    StreamSubscription? sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
        _currentCompleter!.complete();
      }
      sub?.cancel();
    });
    await _player.setSource(AssetSource(path));
    await _player.resume();
    await _currentCompleter?.future;
  }

  Future<void> stop() async {
    await _player.stop();
    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter!.complete();
    }
  }

  List<String> get allAudioNames => _audioBox.keys.cast<String>().toList();

  Future<bool> saveAudio(String n, Uint8List b) async {
    try {
      final sanitized = _sanitizeKey(n);
      await _audioBox.put(sanitized, b);
      _memoryCache[sanitized] = b;
      return true;
    } catch (e) {
      return false;
    }
  }

  bool hasLocalAudio(String name) => _audioBox.containsKey(_sanitizeKey(name));

  String generateUniqueName(String base) {
    String name = _sanitizeKey(base);
    if (_audioBox.containsKey(name)) {
      int i = 1;
      while (_audioBox.containsKey("${name}_[$i]")) i++;
      return "${name}_[$i]";
    }
    return name;
  }

  Future<void> renameAudio(String o, String n) async {
    final oldSanitized = _sanitizeKey(o);
    final newSanitized = _sanitizeKey(n);
    final b = await _audioBox.get(oldSanitized);
    if (b != null) {
      await _audioBox.put(newSanitized, b);
      await _audioBox.delete(oldSanitized);
      _memoryCache.remove(oldSanitized);
      _memoryCache[newSanitized] = b;
    }
  }

  Future<void> deleteAudio(String n) async {
    final sanitized = _sanitizeKey(n);
    await _audioBox.delete(sanitized);
    _memoryCache.remove(sanitized);
  }

  Future<void> exportSingle(String n) async {
    final sanitized = _sanitizeKey(n);
    final b = await _audioBox.get(sanitized);
    if (b != null) downloadFile(b, "$sanitized.mp3");
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
        final fileName = _sanitizeKey(file.name.split('/').last);
        extracted[fileName] = Uint8List.fromList(file.content as List<int>);
      }
    }
    return extracted;
  }
}
