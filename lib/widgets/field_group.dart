import 'package:flutter/material.dart';

/// Rounded, theme-aware card container used to group related form fields
/// across the app. Pass [cardColor]/[borderColor] when the caller already
/// computed them (e.g. to match sibling elements on the same screen);
/// otherwise they default to the standard dark/light card colors used
/// throughout the app (see CLAUDE.md's card-surface convention).
class FieldGroup extends StatelessWidget {
  final Widget child;
  final Color? cardColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final bool expand;

  const FieldGroup({
    super.key,
    required this.child,
    this.cardColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedCardColor = cardColor ?? (isDark ? const Color(0xFF141414) : Colors.white);
    final resolvedBorderColor = borderColor ??
        (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.12));

    return Container(
      width: expand ? double.infinity : null,
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: resolvedBorderColor),
      ),
      child: child,
    );
  }
}
