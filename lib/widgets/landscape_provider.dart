import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class LandscapeChangeNotifier extends ChangeNotifier
    implements ReassembleHandler {
  bool _landscape = false;

  bool get landscape => _landscape;

  LandscapeChangeNotifier(this._landscape);

  void setLandscape(bool landscape) {
    if (_landscape == landscape) return;
    _landscape = landscape;
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
