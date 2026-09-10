import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/info_pill.dart';
import 'remision.dart';

const _accentYellow = AppColors.accent;

/// "Mis entregas del día"'s conteo-de-rutas summary — asignadas (every
/// Remisión found for today, regardless of hito), en ruta (already out of
/// planta per `HitoEntrega.enRutaHitos`), entregadas, and pendientes
/// (everything else: not yet out of planta, or `conIncidencia`/`con_atraso`
/// needing attention). [enRuta] + [entregadas] + [pendientes] always add up
/// to [asignadas] by construction — see `DeliveriesScreen.build`.
class RutasResumenCard extends StatelessWidget {
  final int asignadas;
  final int enRuta;
  final int entregadas;
  final int pendientes;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const RutasResumenCard({
    super.key,
    required this.asignadas,
    required this.enRuta,
    required this.entregadas,
    required this.pendientes,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _divisor() => Container(width: 1, height: 30, color: borderColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _stat('Asignadas', asignadas, textColor),
          _divisor(),
          _stat('En ruta', enRuta, _accentYellow),
          _divisor(),
          _stat('Entregadas', entregadas, AppColors.success),
          _divisor(),
          _stat('Pendientes', pendientes, AppColors.warning),
        ],
      ),
    );
  }
}

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
      color = AppColors.success;
      label = hito.label;
    } else if (hito == HitoEntrega.conIncidencia) {
      color = AppColors.error;
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
