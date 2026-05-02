import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/contact_item.dart';
import '../storage/app_theme.dart';
import '../widgets/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeChangeNotifier>(
      builder: (context, notifier, child) {
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(8.0),
          children: [
            ExpansionTile(
              title: const Text('主題與色系'),
              subtitle: Text('當前：${notifier.theme.uiName}'),
              leading: const Icon(Icons.display_settings),
              shape: Border.all(color: Colors.transparent),
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                SegmentedButton<AppTheme>(
                  segments: AppTheme.values
                      .map(
                        (e) => ButtonSegment(
                          value: e,
                          label: Text(e.uiName),
                          icon: e.icon,
                        ),
                      )
                      .toList(),
                  selected: {notifier.theme},
                  onSelectionChanged: (value) => notifier.setTheme(value.first),
                ),
                ListTile(
                  leading: const Icon(Icons.colorize),
                  title: const Text('自訂強調色'),
                  trailing: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColoredBox(
                      color: theme.colorScheme.primary,
                      child: const SizedBox(width: 40, height: 40),
                    ),
                  ),
                  onTap: () => _showColorPickerDialog(context, notifier),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          children: List.generate(
                            ContactItem.contactItems.length,
                            (index) {
                              final item = ContactItem.contactItems[index];
                              return Column(
                                children: [
                                  ListTile(
                                    dense: true,
                                    leading: FaIcon(
                                      item.icon,
                                      size: 26,
                                      color: theme.colorScheme.primary,
                                    ),
                                    title: Text(
                                      item.title,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    trailing: OutlinedButton(
                                      onPressed: () async =>
                                          await launchUrl(Uri.parse(item.url)),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      child: const Text("前往"),
                                    ),
                                    onTap: () async =>
                                        await launchUrl(Uri.parse(item.url)),
                                  ),
                                  if (index <
                                      ContactItem.contactItems.length - 1)
                                    const Divider(
                                      indent: 20,
                                      endIndent: 20,
                                      height: 1,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showColorPickerDialog(
    BuildContext context,
    ThemeChangeNotifier notifier,
  ) {
    Color pickerColor = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('請選擇強調色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              notifier.setAccentColor(null);
              Navigator.of(context).pop();
            },
            child: const Text('預設'),
          ),
          FilledButton(
            onPressed: () {
              notifier.setAccentColor(pickerColor);
              Navigator.of(context).pop();
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}
