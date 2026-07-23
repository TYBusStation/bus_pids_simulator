import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> downloadFile(Uint8List bytes, String fileName) async {
  await FilePicker.saveFile(fileName: fileName, bytes: bytes);
}

Future<void> downloadFileFromUrl(String url, String fileName) async {
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    print("無法開啟下載連結: $url");
  }
}

Future<void> toggleFullscreen(bool enable) async {
  if (enable) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } else {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

Future<void> setOrientation(bool landscape) async {
  if (landscape) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
}
