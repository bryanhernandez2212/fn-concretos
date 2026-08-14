import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/vehiculo.dart';
import 'vehicle.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Read-only list of pendientes already reported on this vehicle (`GET
/// /pendientes-vehiculos?vehiculoId=`) — falla mecánica/llanta/mantenimiento
/// reports made via `VehiclePendingScreen`, whoever made them. Resolving one
/// (`PATCH .../resolver`) is a workshop/dirección action, not wired here.
class VehiclePendientesScreen extends StatefulWidget {
  final VehiculoResumen vehiculo;

  const VehiclePendientesScreen({super.key, required this.vehiculo});

  @override
  State<VehiclePendientesScreen> createState() => _VehiclePendientesScreenState();
}

class _VehiclePendientesScreenState extends State<VehiclePendientesScreen> {
  late final Future<List<VehiculoPendienteResumen>> _pendientesFuture =
      OperacionesService.pendientesVehiculo(widget.vehiculo.id);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendientes Reportados'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<VehiculoPendienteResumen>>(
        future: _pendientesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is AuthException ? error.message : 'No se pudieron cargar los pendientes',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedColor),
                ),
              ),
            );
          }

          final pendientes = snapshot.data!;
          if (pendientes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No hay pendientes reportados para este vehículo', style: TextStyle(color: mutedColor)),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              for (final pendiente in pendientes) ...[
                _PendienteCard(pendiente: pendiente, cardColor: cardColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PendienteCard extends StatelessWidget {
  final VehiculoPendienteResumen pendiente;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _PendienteCard({
    required this.pendiente,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
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
                  Text(pendiente.descripcion, style: TextStyle(fontSize: 13, color: mutedColor)),
                ],
                const SizedBox(height: 8),
                Text(
                  resuelto
                      ? 'Reportado ${_fecha(pendiente.fechaDeteccion)} · resuelto ${_fecha(pendiente.fechaResolucion)}'
                      : 'Reportado ${_fecha(pendiente.fechaDeteccion)}',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
