import 'package:flutter/material.dart';
import '../operaciones/rastreo_gps.dart';
import '../theme/app_colors.dart';

/// Tells the driver which medium is tracking their unit (see `OrigenGps`) —
/// with phone GPS they need to keep navigation open, with Samsara they don't.
class RastreoInfoCard extends StatelessWidget {
  final OrigenGps origen;

  const RastreoInfoCard({super.key, required this.origen});

  @override
  Widget build(BuildContext context) {
    final color = origen == OrigenGps.samsara
        ? AppColors.success
        : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(origen.icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  origen.titulo,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  origen.descripcion,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
