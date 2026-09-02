import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/info_pill.dart';
import 'cotizacion.dart';
import 'visita.dart';

/// Color for a status pill shared across Visitas/Cotizaciones — covers
/// every `estatus` string this role's entities can carry
/// (`asignada`/`visitada`, `negociacion`/`listo`/`convertida`/`cancelada`).
Color estatusColor(String estatus) {
  switch (estatus) {
    case 'visitada':
    case 'convertida':
      return AppColors.success;
    case 'cancelada':
      return AppColors.error;
    case 'listo':
      return AppColors.accent;
    default:
      return AppColors.warning;
  }
}

String estatusLabel(String estatus) {
  switch (estatus) {
    case 'asignada':
      return 'Asignada';
    case 'visitada':
      return 'Visitada';
    case 'cancelada':
      return 'Cancelada';
    case 'negociacion':
      return 'Negociación';
    case 'listo':
      return 'Listo';
    case 'convertida':
      return 'Convertida';
    default:
      return estatus;
  }
}

class EstatusChip extends StatelessWidget {
  final String estatus;

  const EstatusChip({super.key, required this.estatus});

  @override
  Widget build(BuildContext context) {
    final color = estatusColor(estatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        estatusLabel(estatus),
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color cardColor;
  final Color borderColor;
  final Color mutedColor;

  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    required this.cardColor,
    required this.borderColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Icon(icon, color: mutedColor, size: 28),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(fontSize: 13.5, color: mutedColor), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color cardColor;
  final Color borderColor;
  final Color mutedColor;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    required this.cardColor,
    required this.borderColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(fontSize: 13.5, color: mutedColor), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class VisitaCard extends StatelessWidget {
  final Visita visita;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const VisitaCard({
    super.key,
    required this.visita,
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      visita.obraNombre ?? visita.clienteNombre ?? 'Visita sin obra',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ),
                  EstatusChip(estatus: visita.estatus),
                ],
              ),
              if (visita.clienteNombre != null) ...[
                const SizedBox(height: 4),
                Text(visita.clienteNombre!, style: TextStyle(fontSize: 13, color: mutedColor)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (visita.horaCheckin != null)
                    InfoPill(icon: Icons.access_time, text: visita.horaCheckin!, mutedColor: mutedColor, textColor: textColor),
                  if (visita.contactoNombre != null) ...[
                    const SizedBox(width: 8),
                    InfoPill(icon: Icons.person_outline, text: visita.contactoNombre!, mutedColor: mutedColor, textColor: textColor),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CotizacionCard extends StatelessWidget {
  final Cotizacion cotizacion;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const CotizacionCard({
    super.key,
    required this.cotizacion,
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(cotizacion.clienteNombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                  ),
                  Text(cotizacion.folio, style: TextStyle(fontSize: 12, color: mutedColor)),
                ],
              ),
              if (cotizacion.obraNombre != null) ...[
                const SizedBox(height: 4),
                Text(cotizacion.obraNombre!, style: TextStyle(fontSize: 13, color: mutedColor)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  InfoPill(
                    icon: Icons.water_drop_outlined,
                    text: '${cotizacion.volumenM3} m³',
                    mutedColor: mutedColor,
                    textColor: textColor,
                  ),
                  const SizedBox(width: 8),
                  InfoPill(
                    icon: Icons.payments_outlined,
                    text: '\$${cotizacion.montoTotal.toStringAsFixed(0)}',
                    mutedColor: mutedColor,
                    textColor: textColor,
                  ),
                  const Spacer(),
                  EstatusChip(estatus: cotizacion.estatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
