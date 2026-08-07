import 'package:flutter/material.dart';

class NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Floating pill-shaped bottom navigation bar: icon-only items, with the
/// active icon highlighted inside a solid accent-colored circle.
class BottomNavBar extends StatelessWidget {
  static const double height = 64;
  static const double bottomMargin = 16;

  /// Space scrollable screens must reserve at the bottom so their content
  /// can clear the floating bar instead of being hidden behind it.
  static double clearance(BuildContext context) {
    return MediaQuery.of(context).padding.bottom + height + bottomMargin;
  }

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFFFFCC00);
    final barColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inactiveColor = isDark ? Colors.white54 : Colors.black45;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, bottomMargin),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final isSelected = index == currentIndex;
            final item = items[index];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(index),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? Colors.black : inactiveColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
