import 'dart:html' as html;
import 'dart:typed_data';

void downloadFile(Uint8List bytes, String name) {
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..target = "_blank"
    ..setAttribute("download", name);

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  Future.delayed(const Duration(seconds: 5), () {
    html.Url.revokeObjectUrl(url);
  });
}
