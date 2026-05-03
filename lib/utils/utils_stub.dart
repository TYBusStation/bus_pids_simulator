import 'dart:developer';
import 'dart:typed_data';

void downloadFile(Uint8List bytes, String fileName) {
  log("目前平台不支援瀏覽器下載功能，檔案 $fileName 已產生但未儲存。");
}
