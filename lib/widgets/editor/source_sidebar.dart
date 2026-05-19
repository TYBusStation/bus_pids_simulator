import 'package:flutter/material.dart';

import '../../utils/static.dart';

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
    final List<String> cityKeys = Static.availableCities;

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
        child: ListView.builder(
          itemCount: cityKeys.length,
          itemBuilder: (context, index) {
            final key = cityKeys[index];
            final isSelected = selectedSources.contains(key);
            final bool isLoaded =
                Static.routeData.containsKey(key) &&
                Static.routeData[key]!.isNotEmpty;

            return InkWell(
              onTap: () => onSourceToggle(key),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor, width: 0.5),
                  ),
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.3)
                      : null,
                ),
                child: Text(
                  "${key == 'Custom' ? '自定義' : key}${isLoaded || key == 'Custom' ? '' : '\n(未載入)'}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
