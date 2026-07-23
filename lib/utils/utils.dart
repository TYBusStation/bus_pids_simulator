import 'dart:typed_data';

Future<void> downloadFile(Uint8List bytes, String fileName) async {
  throw UnsupportedError(
    'Cannot download file without platform implementation',
  );
}

void downloadFileFromUrl(String url, String fileName) {
  throw UnsupportedError(
    'Cannot download file without platform implementation',
  );
}

Future<void> toggleFullscreen(bool enable) async {
  throw UnsupportedError("Fullscreen not supported on this platform");
}

Future<void> setOrientation(bool landscape) async {
  throw UnsupportedError("Orientation lock not supported on this platform");
}
