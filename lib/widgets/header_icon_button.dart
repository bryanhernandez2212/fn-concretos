import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A tab header's action icon, styled to match `NotificationBellButton`'s
/// circular chip (same size/tint/border/shadow, just no badge/polling) —
/// so a screen's own action icon (e.g. "Historial", "Agregar obra") doesn't
/// read as a mismatched bare `IconButton` sitting next to the bell. Only
/// for the custom header-row pattern tab bodies build themselves (no
/// `AppBar`) — a real `Scaffold.appBar`'s `actions` already has its own
/// standard Material convention and shouldn't switch to this.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const HeaderIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.surfaceAlt(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: isDark ? 0.85 : 0.95),
              border: Border.all(color: AppColors.border(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: Icon(icon, color: AppColors.text(context), size: 22)),
          ),
        ),
      ),
    );
  }
}
