import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const _accentYellow = AppColors.accent;

/// The "Datos" / "Reportes" switch at the top of `VehicleScreen`.
/// [reportesBadge] is how many things need attention on the Reportes side
/// (open pendientes + documents not vigente), shown as a count on that tab
/// so the driver notices even while looking at Datos.
class VehicleTabSelector extends StatelessWidget {
  final bool verReportes;
  final int reportesBadge;
  final ValueChanged<bool> onChanged;

  const VehicleTabSelector({
    super.key,
    required this.verReportes,
    required this.reportesBadge,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);

    Widget segmento(
      String label,
      IconData icon,
      bool seleccionado,
      VoidCallback onTap, {
      int badge = 0,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: seleccionado ? _accentYellow : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: seleccionado ? AppColors.onAccent : textColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: seleccionado ? AppColors.onAccent : textColor,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          segmento(
            'Datos',
            Icons.local_shipping_outlined,
            !verReportes,
            () => onChanged(false),
          ),
          segmento(
            'Reportes',
            Icons.assignment_late_outlined,
            verReportes,
            () => onChanged(true),
            badge: reportesBadge,
          ),
        ],
      ),
    );
  }
}
