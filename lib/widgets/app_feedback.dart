import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum _FeedbackKind { success, error, info }

/// Branded replacement for the app's plain default `SnackBar` calls —
/// floating, rounded, colored icon + accent border by kind, themed
/// background matching the rest of the app's card surfaces (near-black in
/// dark mode, white in light mode) instead of Material's default grey bar.
class AppSnack {
  static void success(BuildContext context, String message) => _show(context, message, _FeedbackKind.success);

  static void error(BuildContext context, String message) => _show(context, message, _FeedbackKind.error);

  static void info(BuildContext context, String message) => _show(context, message, _FeedbackKind.info);

  static void _show(BuildContext context, String message, _FeedbackKind kind) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final IconData icon;
    final Color accent;
    switch (kind) {
      case _FeedbackKind.success:
        icon = Icons.check_circle_outline;
        accent = AppColors.success;
        break;
      case _FeedbackKind.error:
        icon = Icons.error_outline;
        accent = AppColors.error;
        break;
      case _FeedbackKind.info:
        icon = Icons.info_outline;
        accent = AppColors.accent;
        break;
    }

    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          elevation: 6,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accent.withValues(alpha: 0.4)),
          ),
          duration: const Duration(seconds: 3),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
