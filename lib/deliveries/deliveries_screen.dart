import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'delivery_detail_screen.dart';
import 'remision.dart';

const _accentYellow = Color(0xFFFFCC00);

/// "Mis entregas del día" — the operador de olla's main tab: every Remisión
/// assigned to their vehicle/shift today. Tapping one will open its detail
/// (hitos, firma, foto) once that view exists; for now it's a stub.
class DeliveriesScreen extends StatelessWidget {
  const DeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final pendientes = misEntregasDeHoy.where((r) => r.hitoActual != HitoEntrega.entregaCompleta && r.hitoActual != HitoEntrega.remisionFirmada).length;

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
                    Text(
                      'Mis entregas del día',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
                    ),
                    Text(
                      '$pendientes pendientes de ${misEntregasDeHoy.length}',
                      style: TextStyle(fontSize: 13, color: mutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (final remision in misEntregasDeHoy) ...[
            _RemisionCard(
              remision: remision,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => DeliveryDetailScreen(remision: remision)),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RemisionCard extends StatelessWidget {
  final Remision remision;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _RemisionCard({
    required this.remision,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      remision.obra,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ),
                  _HitoChip(hito: remision.hitoActual),
                ],
              ),
              const SizedBox(height: 4),
              Text(remision.cliente, style: TextStyle(fontSize: 13, color: mutedColor)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 15, color: mutedColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      remision.direccion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: mutedColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoPill(icon: Icons.access_time, text: remision.horaProgramada, mutedColor: mutedColor, textColor: textColor),
                  const SizedBox(width: 8),
                  _InfoPill(icon: Icons.water_drop_outlined, text: '${remision.volumenM3} m³', mutedColor: mutedColor, textColor: textColor),
                  const SizedBox(width: 8),
                  _InfoPill(icon: Icons.grain, text: remision.tipoConcreto, mutedColor: mutedColor, textColor: textColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color mutedColor;
  final Color textColor;

  const _InfoPill({required this.icon, required this.text, required this.mutedColor, required this.textColor});

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

/// Status chip summarizing where a Remisión sits in its 9-step hito chain:
/// muted before it starts moving, brand yellow while in progress, green
/// once fully delivered/signed.
class _HitoChip extends StatelessWidget {
  final HitoEntrega hito;

  const _HitoChip({required this.hito});

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (hito == HitoEntrega.entregaCompleta || hito == HitoEntrega.remisionFirmada) {
      color = const Color(0xFF4CAF50);
    } else if (hito == HitoEntrega.pedidoAsignado || hito == HitoEntrega.cargaEnPlanta) {
      color = Colors.grey;
    } else {
      color = _accentYellow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        hito.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
