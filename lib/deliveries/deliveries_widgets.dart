import 'package:flutter/material.dart';
import 'remision.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Delivery summary card shared with `HistorialEntregasScreen` so past-day
/// entregas render identically to today's.
class RemisionCard extends StatelessWidget {
  final Remision remision;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const RemisionCard({
    super.key,
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
                  HitoChip(hito: remision.hitoActual),
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
                  InfoPill(icon: Icons.access_time, text: remision.horaProgramada, mutedColor: mutedColor, textColor: textColor),
                  const SizedBox(width: 8),
                  InfoPill(icon: Icons.water_drop_outlined, text: '${remision.volumenM3} m³', mutedColor: mutedColor, textColor: textColor),
                  const SizedBox(width: 8),
                  InfoPill(icon: Icons.grain, text: remision.tipoConcreto, mutedColor: mutedColor, textColor: textColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Status chip summarizing where a Remisión sits in its 9-step hito chain:
/// muted before it starts moving, brand yellow while in progress, green
/// once fully delivered/signed. A null hito means no Remisión exists yet
/// (still just today's production programming) — shown as a plain
/// "Programado" chip.
class HitoChip extends StatelessWidget {
  final HitoEntrega? hito;

  const HitoChip({super.key, required this.hito});

  @override
  Widget build(BuildContext context) {
    final hito = this.hito;
    final Color color;
    final String label;
    if (hito == null) {
      color = Colors.grey;
      label = 'Programado';
    } else if (hito == HitoEntrega.entregado) {
      color = const Color(0xFF4CAF50);
      label = hito.label;
    } else if (hito == HitoEntrega.conIncidencia) {
      color = const Color(0xFFEF5350);
      label = hito.label;
    } else if (hito == HitoEntrega.cargandoPlanta) {
      color = Colors.grey;
      label = hito.label;
    } else {
      color = _accentYellow;
      label = hito.label;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
