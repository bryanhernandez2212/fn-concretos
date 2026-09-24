import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'pedido.dart';

const _accentYellow = AppColors.accent;
const _green = AppColors.success;
const _red = AppColors.error;

class SummaryCard extends StatelessWidget {
  final Pedido pedido;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const SummaryCard({
    super.key,
    required this.pedido,
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
            pedido.obraNombre,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            pedido.clienteNombre,
            style: TextStyle(fontSize: 13.5, color: mutedColor),
          ),
          const SizedBox(height: 14),
          Line(
            icon: Icons.water_drop_outlined,
            text: '${pedido.volumenSolicitadoM3} m³ · ${pedido.tipoServicio}',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          Line(
            icon: Icons.payments_outlined,
            text:
                'Condición: ${pedido.condicionPago}${pedido.diasCredito != null ? ' · ${pedido.diasCredito} días' : ''}',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          if (pedido.fechaProgramada != null) ...[
            const SizedBox(height: 8),
            Line(
              icon: Icons.event_outlined,
              text: 'Programada: ${pedido.fechaProgramada}',
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ],
          if (pedido.estatusGeneral == 'parcial' ||
              pedido.estatusGeneral == 'completo' ||
              pedido.volumenEntregadoM3 > 0) ...[
            const SizedBox(height: 14),
            _EntregaProgress(
              pedido: pedido,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ],
        ],
      ),
    );
  }
}

/// Delivery progress bar — `volumenEntregadoM3`/`estatusGeneral` update in
/// real time as each remisión gets firmada (the signature flow triggers
/// `comercial-service`'s internal entrega-tracking on the backend), so this
/// reflects actual accumulated delivery, not a static request snapshot.
class _EntregaProgress extends StatelessWidget {
  final Pedido pedido;
  final Color textColor;
  final Color mutedColor;

  const _EntregaProgress({
    required this.pedido,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final completo = pedido.estatusGeneral == 'completo';
    final color = completo ? _green : _accentYellow;
    final fraction = pedido.volumenSolicitadoM3 > 0
        ? (pedido.volumenEntregadoM3 / pedido.volumenSolicitadoM3).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Entrega',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            if (completo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Completo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: mutedColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${pedido.volumenEntregadoM3} / ${pedido.volumenSolicitadoM3} m³ entregado',
          style: TextStyle(fontSize: 12.5, color: mutedColor),
        ),
      ],
    );
  }
}

class Line extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;
  final Color mutedColor;

  const Line({
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

/// Either the Aprobar/Rechazar buttons (when `estatus == 'pendiente'`) or a
/// static chip showing the already-recorded result.
class AutorizacionSection extends StatelessWidget {
  final String estatus;
  final bool submitting;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final Color textColor;
  final Color mutedColor;

  const AutorizacionSection({
    super.key,
    required this.estatus,
    required this.submitting,
    required this.onAprobar,
    required this.onRechazar,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    if (estatus != 'pendiente') {
      final aprobado = estatus == 'aprobado';
      final color = aprobado
          ? _green
          : (estatus == 'rechazado' ? _red : mutedColor);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              aprobado ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              estatus,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: submitting ? null : onRechazar,
            style: OutlinedButton.styleFrom(
              foregroundColor: _red,
              side: const BorderSide(color: _red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Rechazar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: submitting ? null : onAprobar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Aprobar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

class PlaceholderCard extends StatelessWidget {
  final String text;
  final Color cardColor;
  final Color borderColor;
  final Color mutedColor;

  const PlaceholderCard({
    super.key,
    required this.text,
    required this.cardColor,
    required this.borderColor,
    required this.mutedColor,
  });

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
      child: Text(text, style: TextStyle(fontSize: 13.5, color: mutedColor)),
    );
  }
}
