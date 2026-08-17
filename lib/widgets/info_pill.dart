import 'package:flutter/material.dart';

/// Small rounded chip pairing an icon with a short label, used across list
/// cards (pedidos, remisiones) to surface a secondary piece of info.
class InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color mutedColor;
  final Color textColor;

  const InfoPill({super.key, required this.icon, required this.text, required this.mutedColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: mutedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}
