import 'package:flutter/material.dart';
import '../operaciones/evidencia.dart';
import '../theme/app_colors.dart';
import '../widgets/evidencia_viewer_screen.dart';
import '../widgets/field_group.dart';
import 'remision.dart';

const _accentYellow = AppColors.accent;

class SummaryCard extends StatelessWidget {
  final Remision remision;

  /// This remisión's own folio (`RemisionResumen.folioRemision`, only known
  /// once `remisionDetalle` loads) — distinct from `remision.folio`, which
  /// is the *pedido*'s folio. Null/empty while the detail hasn't loaded yet
  /// or no Remisión exists.
  final String? folioRemision;

  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const SummaryCard({
    super.key,
    required this.remision,
    this.folioRemision,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            remision.obra,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            remision.cliente,
            style: TextStyle(fontSize: 13.5, color: mutedColor),
          ),
          if (folioRemision != null && folioRemision!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 15,
                  color: _accentYellow,
                ),
                const SizedBox(width: 6),
                Text(
                  'Remisión $folioRemision · ${remision.volumenM3} m³',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          DetailLine(
            icon: Icons.location_on_outlined,
            text: remision.direccion,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          DetailLine(
            icon: Icons.access_time,
            text: 'Programada: ${remision.horaProgramada}',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          DetailLine(
            icon: Icons.grain,
            text: '${remision.tipoConcreto} · ${remision.volumenM3} m³',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          DetailLine(
            icon: Icons.water_drop_outlined,
            text: 'Pedido total: ${remision.volumenPedidoTotal} m³',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          //metros entregados 
          DetailLine(
            icon: Icons.check_circle_outline,
            text: 'm³ entregados ${remision.volumenPedidoEntregado} m³',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          //metros pendientes
          DetailLine(
            icon: Icons.access_time_outlined,
            text: 'm³ pendientes ${remision.volumenPedidoPendiente} m³',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          
        ],
      ),
    );
  }
}

class DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;
  final Color mutedColor;

  const DetailLine({
    super.key,
    required this.icon,
    required this.text,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: mutedColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13.5, color: textColor)),
        ),
      ],
    );
  }
}

/// Rounded card wrapper matching the style used across the rest of the app.
/// Real hito timestamps stamped by the backend (`RemisionResumen.hora*`) —
/// only the ones that already happened are passed in, so this only ever
/// renders entries with a non-null `DateTime`.
class HorariosCard extends StatelessWidget {
  final List<(String, DateTime?)> horarios;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const HorariosCard({
    super.key,
    required this.horarios,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  static String _formatHora(DateTime hora) {
    final local = hora.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return FieldGroup(
      cardColor: cardColor,
      borderColor: borderColor,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, entry) in horarios.indexed) ...[
              if (index > 0) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.$1,
                      style: TextStyle(fontSize: 13.5, color: mutedColor),
                    ),
                  ),
                  Text(
                    _formatHora(entry.$2!),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One row of the hito stepper: a filled/checked circle for done steps, a
/// highlighted circle for the current one, an outlined circle for what's
/// ahead, connected by a vertical line.
class HitoRow extends StatelessWidget {
  final HitoEntrega hito;

  /// Null means nothing has been registered yet (a blank `estatus`) — every
  /// row renders as pending, none done/current.
  final HitoEntrega? current;
  final bool isLast;
  final Color textColor;
  final Color mutedColor;

  const HitoRow({
    super.key,
    required this.hito,
    required this.current,
    required this.isLast,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    // Each hito is a server-stamped instant (`avanzarHito` records a `hora*`
    // the moment it's PATCHed), not a duration — so reaching it, including
    // being the most recently reached one, already means it happened. There's
    // no separate "in progress" state to show for the current hito: it's
    // done (green, checked) the same as every earlier one.
    final isDone = current != null && hito.index <= current.index;
    final isCurrent = current != null && hito.index == current.index;
    final circleColor = isDone ? AppColors.success : mutedColor.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? circleColor : Colors.transparent,
                  border: Border.all(color: circleColor, width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  color: mutedColor.withValues(alpha: 0.2),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hito.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent || isDone ? textColor : mutedColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  /// Optional status pill shown before the chevron (e.g. "Firmada") once
  /// this action has already been completed. Null shows no pill.
  final String? statusLabel;
  final Color? statusColor;

  /// When false, the row stays visible (so the driver knows the action
  /// exists and roughly when it'll unlock) but doesn't respond to taps and
  /// renders dimmed — icon/text/chevron all fall back to [mutedColor]
  /// instead of their normal accent/text colors.
  final bool enabled;

  const ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
    this.statusLabel,
    this.statusColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: enabled ? _accentYellow : mutedColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: enabled ? textColor : mutedColor,
                  ),
                ),
              ),
              if (statusLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (statusColor ?? mutedColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor ?? mutedColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapping grid of tappable evidencia thumbnails, one per archivo already
/// attached to the remisión. Deliberately a `Wrap`, not a horizontal
/// `ListView` — a nested scrollable of a different axis inside the outer
/// vertical `ListView` fought it for the drag gesture (visible as a
/// stutter/rubber-band whenever you reversed scroll direction near this
/// strip, since it sits near the bottom of `DeliveryDetailScreen`). A `Wrap`
/// has no scroll behavior of its own, so there's nothing left to compete.
class EvidenciaThumbnailStrip extends StatelessWidget {
  final List<ArchivoResponse> archivos;
  final Color borderColor;

  const EvidenciaThumbnailStrip({
    super.key,
    required this.archivos,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final archivo in archivos)
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EvidenciaViewerScreen(
                    url: archivo.archivoUrl,
                    label: 'Evidencia de entrega',
                  ),
                  fullscreenDialog: true,
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                ),
                child: Image.network(
                  archivo.archivoUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 128,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image_outlined, size: 20),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
