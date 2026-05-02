import 'dart:ui';

import 'package:bus_pids_simulator/storage/storage.dart';

import 'app_theme.dart';

class LocalStorage {
  static const String defaultGroupName = '最愛';

  AppTheme get appTheme => AppTheme.values.byName(
      StorageHelper.get<String>('app_theme', AppTheme.followSystem.name));

  set appTheme(AppTheme value) =>
      StorageHelper.set<String>('app_theme', value.name);

  Color get accentColor =>
      Color(StorageHelper.get<int>('accent_color', 0xFFD0BCFF));

  set accentColor(Color? value) =>
      StorageHelper.set<int?>('accent_color', value?.toARGB32());
}
