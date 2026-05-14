import 'package:flutter/material.dart';

class SourceSidebar extends StatelessWidget {
  final Set<String> selectedSources;
  final Function(String) onSourceToggle;

  const SourceSidebar({
    super.key,
    required this.selectedSources,
    required this.onSourceToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = {
      'Taoyuan': '桃園市',
      'Taipei': '臺北市',
      'NewTaipei': '新北市',
      'Taichung': '臺中市',
      'InterCity': '公路客運',
    };

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: Container(
        width: 75,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.9),
          border: Border(left: BorderSide(color: theme.dividerColor)),
        ),
        child: ListView(
          children: sources.entries
              .map(
                (e) => InkWell(
                  onTap: () => onSourceToggle(e.key),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor,
                          width: 0.5,
                        ),
                      ),
                      color: selectedSources.contains(e.key)
                          ? theme.colorScheme.primary.withOpacity(0.3)
                          : null,
                    ),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: selectedSources.contains(e.key)
                            ? theme.colorScheme.primary
                            : Colors.white70,
                        fontWeight: selectedSources.contains(e.key)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
