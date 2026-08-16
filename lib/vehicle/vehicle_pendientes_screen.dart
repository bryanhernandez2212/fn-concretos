import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/vehiculo.dart';
import 'vehicle_pendientes_widgets.dart';

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
                PendienteCard(pendiente: pendiente, cardColor: cardColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}
