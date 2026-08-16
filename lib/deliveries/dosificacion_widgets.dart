import 'package:flutter/material.dart';

const _accentYellow = Color(0xFFFFCC00);

class FieldGroup extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Widget child;

  const FieldGroup({super.key, required this.cardColor, required this.borderColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class IngredienteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unidad;
  final Color textColor;
  final Color mutedColor;
  final bool requerido;

  const IngredienteField({
    super.key,
    required this.controller,
    required this.label,
    required this.unidad,
    required this.textColor,
    required this.mutedColor,
    this.requerido = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045);

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: requerido ? label : '$label (opcional)',
        suffixText: unidad,
        suffixStyle: TextStyle(color: mutedColor),
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
