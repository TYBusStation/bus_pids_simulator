import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final bool isFabMenuExpanded;
  final double brightness;
  final VoidCallback onToggleFab, onRecenter;
  final Function(double) onBrightnessChanged;

  const MapControls({
    super.key,
    required this.isFabMenuExpanded,
    required this.brightness,
    required this.onToggleFab,
    required this.onRecenter,
    required this.onBrightnessChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isFabMenuExpanded) ...[
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              width: 32,
              height: 90,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.brightness_6,
                    size: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 1.5,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 4.0,
                          ),
                        ),
                        child: Slider(
                          value: brightness,
                          activeColor: theme.colorScheme.primary,
                          onChanged: onBrightnessChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isFabMenuExpanded) ...[
              SizedBox(
                width: 34,
                height: 34,
                child: FloatingActionButton.small(
                  onPressed: onRecenter,
                  heroTag: 'rec',
                  child: const Icon(Icons.center_focus_strong, size: 16),
                ),
              ),
              const SizedBox(width: 4),
            ],
            SizedBox(
              width: 38,
              height: 38,
              child: FloatingActionButton(
                onPressed: onToggleFab,
                heroTag: 'm',
                child: Icon(
                  isFabMenuExpanded ? Icons.close : Icons.menu_open,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
