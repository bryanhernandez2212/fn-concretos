import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'vehicle.dart';
import 'vehicle_documents_screen.dart';
import 'vehicle_pending_screen.dart';

const _accentYellow = Color(0xFFFFCC00);

/// "Mi vehículo" tab: unit summary plus entry points to report a pendiente
/// (falla/llanta/mantenimiento) and to check document expirations.
class VehicleScreen extends StatelessWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final docsPorAtender = vehiculoDocumentos.where((d) => d.estado != VehiculoDocumentoEstado.vigente).length;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, BottomNavBar.clearance(context) + 16),
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentYellow.withValues(alpha: 0.18),
                ),
                child: const Icon(Icons.local_shipping_outlined, color: _accentYellow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mi vehículo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                    Text(vehiculoModelo, style: TextStyle(fontSize: 13, color: mutedColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.numbers, color: mutedColor, size: 18),
                const SizedBox(width: 8),
                Text('Placa', style: TextStyle(fontSize: 13, color: mutedColor)),
                const Spacer(),
                Text(vehiculoPlaca, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _NavCard(
            icon: Icons.report_problem_outlined,
            title: 'Reportar pendiente del vehículo',
            subtitle: 'Falla mecánica, llanta o mantenimiento',
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const VehiclePendingScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _NavCard(
            icon: Icons.description_outlined,
            title: 'Documentos del vehículo',
            subtitle: docsPorAtender > 0 ? '$docsPorAtender por atender' : 'Todo en regla',
            badgeColor: docsPorAtender > 0 ? const Color(0xFFEF5350) : null,
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const VehicleDocumentsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? badgeColor;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeColor,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentYellow.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: _accentYellow),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (badgeColor != null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                          ),
                        ],
                        Text(subtitle, style: TextStyle(fontSize: 12.5, color: mutedColor)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}
