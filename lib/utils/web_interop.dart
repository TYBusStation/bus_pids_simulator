abstract class WebInterop {
  void hideFlutterLoader();

  void toggleFullscreen();

  factory WebInterop() => getWebInterop();
}

WebInterop getWebInterop() {
  throw UnsupportedError(
    'Cannot create a WebInterop without dart:html or dart:js',
  );
}
