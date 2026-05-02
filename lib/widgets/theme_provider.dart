import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../storage/app_theme.dart';
import '../utils/static.dart';

class ThemeChangeNotifier extends ChangeNotifier implements ReassembleHandler {
  AppTheme _theme;

  AppTheme get theme => _theme;

  ThemeChangeNotifier(this._theme);

  void setTheme(AppTheme theme) {
    if (_theme == theme) return;
    _theme = theme;
    Static.localStorage.appTheme = theme;
    notifyListeners();
  }

  void setAccentColor(Color? color) {
    Static.localStorage.accentColor = color;
    notifyListeners();
  }

  @override
  void reassemble() => setTheme(Static.localStorage.appTheme);
}

class ThemeProvider extends StatelessWidget {
  final Widget Function(BuildContext context, ThemeData themeData) builder;

  const ThemeProvider({super.key, required this.builder});

  static ThemeChangeNotifier of(BuildContext context) =>
      Provider.of<ThemeChangeNotifier>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeChangeNotifier>(
      builder: (context, notifier, _) {
        // 計算亮暗色
        final Brightness brightness = (notifier.theme == AppTheme.followSystem)
            ? View.of(context).platformDispatcher.platformBrightness
            : (notifier.theme == AppTheme.dark
                  ? Brightness.dark
                  : Brightness.light);

        final themeData = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Static.localStorage.accentColor ?? Colors.blue,
            brightness: brightness,
          ),
          useMaterial3: true,
          fontFamily: GoogleFonts.notoSansTc().fontFamily,
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedLabelStyle: TextStyle(fontSize: 14),
            unselectedLabelStyle: TextStyle(fontSize: 12),
          ),
        );

        return builder(context, themeData);
      },
    );
  }
}
