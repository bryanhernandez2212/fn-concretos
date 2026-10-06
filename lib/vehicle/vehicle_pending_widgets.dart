import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const _accentYellow = AppColors.accent;

/// Numbered step heading ("1 · ¿Qué tipo de problema?") for the report form.
class StepHeader extends StatelessWidget {
  final int numero;
  final String titulo;
  final String? subtitulo;
  final bool completo;

  const StepHeader({
    super.key,
    required this.numero,
    required this.titulo,
    this.subtitulo,
    this.completo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completo ? _accentYellow : Colors.transparent,
              border: Border.all(color: _accentYellow, width: 1.5),
            ),
            alignment: Alignment.center,
            child: completo
                ? const Icon(Icons.check, size: 15, color: AppColors.onAccent)
                : Text(
                    '$numero',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _accentYellow),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text(context)),
                ),
                if (subtitulo != null)
                  Text(subtitulo!, style: TextStyle(fontSize: 12, color: AppColors.mutedText(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Large dashed-feel tile for adding a photo from camera or gallery.
class EvidenciaOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const EvidenciaOptionTile({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _accentYellow.withValues(alpha: 0.45), width: 1.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _accentYellow, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
