export 'web_interop.dart'
    if (dart.library.js_interop) 'web_interop_web.dart'
    if (dart.library.html) 'web_interop_web.dart'
    if (dart.library.io) 'web_interop_android.dart';
