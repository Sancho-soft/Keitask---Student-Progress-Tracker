// keitask_management/lib/widgets/circular_nav_bar.dart (REIMAGINED FOR CURVED BAR STYLE)

import 'package:flutter/material.dart';

class CircularNavBarItem {
  final IconData icon;
  final String label;
  const CircularNavBarItem({required this.icon, required this.label});
}

class CircularNavBar extends StatelessWidget {
  final List<CircularNavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  // NOTE: onCenterTap is not used in this standard bottom bar style
  // final VoidCallback? onCenterTap;

  const CircularNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    // Removed unused size and onCenterTap parameters for this style
  }) : assert(items.length <= 6, 'Support up to 6 items');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The height of a standard bottom navigation bar
    const barHeight = 65.0;

    return SafeArea(
      // Use ClipRRect to apply the rounded corners to the top of the bar
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 6,
          child: SizedBox(
            height: barHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final isSelected = i == currentIndex;

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(i),
                      splashColor: theme.colorScheme.primary.withAlpha(26),
                      highlightColor: Colors.transparent,
                      borderRadius: BorderRadius.zero,
                      child: SizedBox(
                        height: barHeight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated vertical offset + scale for selection
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.only(
                                top: isSelected ? 6.0 : 10.0,
                              ),
                              child: AnimatedScale(
                                scale: isSelected ? 1.18 : 1.0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                child: Icon(
                                  items[i].icon,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withAlpha(
                                          220,
                                        ),
                                  size: isSelected ? 28 : 24,
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Animated text style for the label
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withAlpha(
                                        150,
                                      ),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                              child: Text(items[i].label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
