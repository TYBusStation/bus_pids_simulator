abstract class WebInterop {
  void hideFlutterLoader();

  void lockLandscape();

  void toggleFullscreen();
}

WebInterop getWebInterop() {
  throw UnsupportedError(
    'Cannot create a WebInterop without dart:html or dart:js',
  );
}
