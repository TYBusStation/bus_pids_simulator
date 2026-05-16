import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadFile(Uint8List bytes, String name) {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;

  anchor.href = url;
  anchor.download = name;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();

  web.window.setTimeout((() => web.URL.revokeObjectURL(url)).toJS, null, 5000);
}
