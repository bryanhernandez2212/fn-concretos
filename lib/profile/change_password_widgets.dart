import 'package:flutter/material.dart';

const _accentYellow = Color(0xFFFFCC00);

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const PasswordField({super.key, required this.controller, required this.label});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045);
    final textColor = isDark ? Colors.white : Colors.black87;

    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(Icons.lock_outline, size: 20, color: _accentYellow),
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accentYellow, width: 1.5),
        ),
      ),
    );
  }
}
