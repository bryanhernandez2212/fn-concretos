import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/vehiculo.dart';
import '../theme/app_colors.dart';
import 'vehicle_pendiente_detail_screen.dart';
import 'vehicle_pendientes_widgets.dart';

const _accentYellow = AppColors.accent;

/// Read-only list of pendientes already reported on this vehicle (`GET
/// /pendientes-vehiculos?vehiculoId=`) — falla mecánica/llanta/mantenimiento
/// reports made via `VehiclePendingScreen`, whoever made them. Resolving one
/// (`PATCH .../resolver`) is a workshop/dirección action, not wired here.
///
/// A two-way segmented toggle ("Pendientes" / "Resueltos") switches which
/// half of the list shows, in place — no separate history screen.
class VehiclePendientesScreen extends StatefulWidget {
  final VehiculoResumen vehiculo;

  const VehiclePendientesScreen({super.key, required this.vehiculo});

  @override
  State<VehiclePendientesScreen> createState() => _VehiclePendientesScreenState();
}

class _VehiclePendientesScreenState extends State<VehiclePendientesScreen> {
  late final Future<List<VehiculoPendienteResumen>> _pendientesFuture =
      OperacionesService.pendientesVehiculo(widget.vehiculo.id);
  bool _mostrarResueltos = false;

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
        title: const Text('Reportes'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
          final abiertos = pendientes.where((p) => p.fechaResolucion == null).toList();
          final resueltos = pendientes.where((p) => p.fechaResolucion != null).toList();
          final mostrados = _mostrarResueltos ? resueltos : abiertos;

          Widget segmento(String label, int count, bool seleccionado, VoidCallback onTap) {
            return Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: seleccionado ? _accentYellow : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$label ($count)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: seleccionado ? Colors.black : textColor,
                    ),
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      segmento('Pendientes', abiertos.length, !_mostrarResueltos, () {
                        if (_mostrarResueltos) setState(() => _mostrarResueltos = false);
                      }),
                      segmento('Resueltos', resueltos.length, _mostrarResueltos, () {
                        if (!_mostrarResueltos) setState(() => _mostrarResueltos = true);
                      }),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: mostrados.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _mostrarResueltos
                                ? 'Todavía no hay pendientes resueltos'
                                : 'No hay pendientes abiertos para este vehículo',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: mutedColor),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          for (final pendiente in mostrados) ...[
                            PendienteCard(
                              pendiente: pendiente,
                              cardColor: cardColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              mutedColor: mutedColor,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => VehiclePendienteDetailScreen(pendiente: pendiente),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
