import 'package:flutter/material.dart';
import '../operaciones/vehiculo.dart';
import 'vehicle.dart';

class PendienteCard extends StatelessWidget {
  final VehiculoPendienteResumen pendiente;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const PendienteCard({
    super.key,
    required this.pendiente,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  static String _fecha(DateTime? d) =>
      d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final resuelto = pendiente.fechaResolucion != null;
    final color = resuelto ? const Color(0xFF4CAF50) : const Color(0xFFFFA000);
    final tipo = TipoPendiente.values.where((t) => t.backendValue == pendiente.tipoPendiente);
    final tipoLabel = tipo.isEmpty ? pendiente.tipoPendiente : tipo.first.label;
    final tipoIcon = tipo.isEmpty ? Icons.report_problem_outlined : tipo.first.icon;
    final tieneEvidencia = pendiente.evidenciaApertura != null || pendiente.evidenciaCierre != null;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
                child: Icon(tipoIcon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(tipoLabel, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            resuelto ? 'Resuelto' : 'Abierto',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                          ),
                        ),
                      ],
                    ),
                    if (pendiente.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        pendiente.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: mutedColor),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            resuelto
                                ? 'Reportado ${_fecha(pendiente.fechaDeteccion)} · resuelto ${_fecha(pendiente.fechaResolucion)}'
                                : 'Reportado ${_fecha(pendiente.fechaDeteccion)}',
                            style: TextStyle(fontSize: 12, color: mutedColor),
                          ),
                        ),
                        if (tieneEvidencia) ...[
                          Icon(Icons.photo_camera_outlined, size: 14, color: mutedColor),
                          const SizedBox(width: 12),
                        ],
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
