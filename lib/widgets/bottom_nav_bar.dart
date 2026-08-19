import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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

  /// Shrinks the pill while the active tab's list is scrolling down, and
  /// grows it back while scrolling up — stays at whichever size until the
  /// scroll direction flips again (see home_screen.dart/
  /// direccion_home_screen.dart), not tied to scroll position or idle time.
  final bool compact;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintBase = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inactiveColor = isDark ? Colors.white54 : Colors.black45;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, bottomMargin),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        scale: compact ? 0.82 : 1.0,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              decoration: BoxDecoration(
                // Plain alpha transparency, no BackdropFilter/blur — Impeller on
                // iOS was rendering the blurred version as fully opaque instead
                // of see-through, so this sticks to basic compositing that's
                // guaranteed to work everywhere.
                color: tintBase.withValues(alpha: isDark ? 0.72 : 0.8),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: isDark ? 0.08 : 0.06,
                  ),
                ),
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
                            color: isSelected
                                ? AppColors.accent
                                : Colors.transparent,
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
          ),
        ),
      ),
    );
  }
}
