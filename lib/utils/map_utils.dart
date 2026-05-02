import 'package:flutter/material.dart';

abstract class MapUtils {
  static const List<Color> segmentColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF00897B),
    Color(0xFF5E35B1),
    Color(0xFFFFB300),
    Color(0xFF039BE5),
    Color(0xFF6D4C41),
    Color(0xFFF4511E),
    Color(0xFFC0CA33),
    Color(0xFF00ACC1),
    Color(0xFF7CB342),
    Color(0xFF673AB7),
    Color(0xFF455A64),
  ];
  static List<Color> segmentColorsReverse = segmentColors.reversed.toList();
  static const double defaultZoom = 17;

  static double getPanelHeight(bool isLandscape) {
    return isLandscape ? 100.0 : 160.0;
  }

  static Widget buildInfoChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Chip(
        avatar: Icon(
          icon,
          size: 16,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
        label: Text(label, style: theme.textTheme.labelMedium),
        visualDensity: VisualDensity.compact,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
