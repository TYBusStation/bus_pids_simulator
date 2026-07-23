import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../utils/utils_helper.dart';

class LandscapeChangeNotifier extends ChangeNotifier
    implements ReassembleHandler {
  bool _landscape = false;
  bool _isFullscreen = false;

  bool get landscape => _landscape;

  bool get isFullscreen => _isFullscreen;

  LandscapeChangeNotifier(this._landscape);

  void setLandscape(bool landscape) {
    if (_landscape == landscape) return;
    _landscape = landscape;
    notifyListeners();
  }

  Future<void> toggleRotateAndFullscreen() async {
    _landscape = !_landscape;
    _isFullscreen = _landscape;

    await setOrientation(_landscape);
    await toggleFullscreen(_isFullscreen);

    notifyListeners();
  }

  Future<void> toggleOnlyFullscreen() async {
    _isFullscreen = !_isFullscreen;
    await toggleFullscreen(_isFullscreen);
    notifyListeners();
  }

  @override
  void reassemble() => notifyListeners();
}

class LandscapeProvider extends StatelessWidget {
  final Widget Function(BuildContext context, bool landscape) builder;

  const LandscapeProvider({super.key, required this.builder});

  static LandscapeChangeNotifier of(BuildContext context) =>
      Provider.of<LandscapeChangeNotifier>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    return Consumer<LandscapeChangeNotifier>(
      builder: (context, notifier, _) => builder(context, notifier.landscape),
    );
  }
}
