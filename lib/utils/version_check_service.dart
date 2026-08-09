import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yaml/yaml.dart';

import 'static.dart';

class VersionCheckService {
  final String _versionInfoUrl =
      'https://raw.githubusercontent.com/TYBusStation/bus_pids_simulator/main/pubspec.yaml';
  final String _repoSlug = 'TYBusStation/bus_pids_simulator';

  Future<Map<String, dynamic>?> getLatestVersionInfo() async {
    try {
      final response = await Static.dio.get<String>(_versionInfoUrl);
      if (response.statusCode == 200 && response.data != null) {
        final doc = loadYaml(response.data!);
        final version = (doc['version'] as String).split('+').first;
        return {
          'version': version,
          'url':
              'https://github.com/$_repoSlug/releases/download/v$version/app-release.apk',
        };
      }
    } catch (_) {}
    return null;
  }

  Future<bool> isUpdateRequired() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final packageInfo = await PackageInfo.fromPlatform();
    final current = packageInfo.version;
    final latestInfo = await getLatestVersionInfo();
    if (latestInfo != null) {
      return _compareVersion(latestInfo['version'], current);
    }
    return false;
  }

  bool _compareVersion(String latest, String current) {
    List<int> l = latest.split('.').map(int.parse).toList();
    List<int> c = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      int lv = i < l.length ? l[i] : 0;
      int cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  Future<void> downloadAndInstall(
    String url,
    void Function(double) onProgress,
  ) async {
    if (await Permission.requestInstallPackages.request().isDenied) {
      throw Exception('缺少安裝權限');
    }
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      throw Exception('無法存取外部儲存空間');
    }
    final path = '${dir.path}/update.apk';
    await Static.dio.download(
      url,
      path,
      onReceiveProgress: (received, total) {
        if (total != -1) onProgress(received / total);
      },
    );
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
