import 'package:flutter/material.dart';

class SecretCard extends StatelessWidget {
  final String secret;
  final Color textColor;
  final Color mutedColor;

  const SecretCard({super.key, required this.secret, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Código secreto', style: TextStyle(fontSize: 12, color: mutedColor)),
          const SizedBox(height: 6),
          SelectableText(
            secret,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

/// Rounded card that groups related fields, matching the style used across
/// the rest of the app (see edit_profile_screen.dart).
class FieldGroup extends StatelessWidget {
  final List<Widget> children;

  const FieldGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }
}
