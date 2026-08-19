import 'package:flutter/material.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/vehiculo.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'vehicle.dart';
import 'vehicle_documents_screen.dart';
import 'vehicle_pendientes_screen.dart';
import 'vehicle_pending_screen.dart';
import 'vehicle_screen_widgets.dart';
import 'vehiculo_service.dart';

const _accentYellow = AppColors.accent;

/// "Mi vehículo" tab: unit summary (real, via `VehiculoService.miVehiculo`)
/// plus entry points to report a pendiente (falla/llanta/mantenimiento) and
/// to check document expirations — both real now.
class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  late final Future<VehiculoResumen?> _vehiculoFuture =
      VehiculoService.miVehiculo();

  // Chained off the same cached `_vehiculoFuture` (not re-fetched inline in
  // build) so switching tabs — which rebuilds this screen since HomeScreen
  // keeps every tab mounted — doesn't re-trigger the network calls.
  late final Future<List<VehiculoDocumentoResumen>> _documentosFuture =
      _vehiculoFuture.then(
        (vehiculo) => vehiculo == null
            ? const <VehiculoDocumentoResumen>[]
            : OperacionesService.documentosVehiculo(vehiculo.id),
      );

  late final Future<List<VehiculoMantenimientoResumen>> _mantenimientosFuture =
      _vehiculoFuture.then(
        (vehiculo) => vehiculo == null
            ? const <VehiculoMantenimientoResumen>[]
            : OperacionesService.mantenimientosVehiculo(vehiculo.id),
      );

  late Future<List<VehiculoPendienteResumen>> _pendientesFuture =
      _vehiculoFuture.then(
        (vehiculo) => vehiculo == null
            ? const <VehiculoPendienteResumen>[]
            : OperacionesService.pendientesVehiculo(vehiculo.id),
      );

  void _refrescarPendientes(int vehiculoId) {
    setState(() {
      _pendientesFuture = OperacionesService.pendientesVehiculo(vehiculoId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.55,
    );
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return FutureBuilder<VehiculoResumen?>(
      future: _vehiculoFuture,
      builder: (context, snapshot) {
        final vehiculo = snapshot.data;
        final cargando = snapshot.connectionState != ConnectionState.done;
        final modeloTexto = cargando
            ? 'Cargando...'
            : (vehiculo == null
                  ? 'Sin vehículo asignado'
                  : '${vehiculo.marca} ${vehiculo.modelo}'.trim());

        return ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            BottomNavBar.clearance(context) + 16,
          ),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentYellow,
                  ),
                  child: const Icon(
                    Icons.local_shipping_sharp,
                    color: AppColors.onAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi vehículo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        modeloTexto,
                        style: TextStyle(fontSize: 13, color: mutedColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (vehiculo != null)
              FutureBuilder<List<VehiculoMantenimientoResumen>>(
                future: _mantenimientosFuture,
                builder: (context, mntSnapshot) {
                  final enMantenimiento =
                      mntSnapshot.data?.any((m) => m.activo) ?? false;
                  if (!enMantenimiento) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.build_circle_outlined,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Este vehículo está en mantenimiento',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (cargando)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (vehiculo == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'No tienes ningún vehículo asignado',
                  style: TextStyle(color: mutedColor),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    DetailRow(
                      icon: Icons.numbers,
                      label: 'Número de unidad',
                      value: vehiculo.numeroUnidad,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    DetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Placas',
                      value: vehiculo.placas,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    DetailRow(
                      icon: Icons.category_outlined,
                      label: 'Grupo',
                      value: vehiculo.grupo,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    DetailRow(
                      icon: Icons.description_outlined,
                      label: 'Descripción',
                      value: vehiculo.descripcion,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    DetailRow(
                      icon: Icons.palette_outlined,
                      label: 'Color',
                      value: vehiculo.color,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    DetailRow(
                      icon: Icons.pin_outlined,
                      label: 'VIN',
                      value: vehiculo.numeroSerieVin,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    DetailRow(
                      icon: Icons.toggle_on_outlined,
                      label: 'Estatus',
                      value: vehiculo.estatus,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    DetailRow(
                      icon: Icons.gps_fixed,
                      label: 'GPS',
                      value: vehiculo.gpsInstalado,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    DetailRow(
                      icon: Icons.videocam_outlined,
                      label: 'Cámara instalada',
                      value: vehiculo.camaraInstalada ? 'Sí' : 'No',
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    DetailRow(
                      icon: Icons.build_circle_outlined,
                      label: 'Último servicio',
                      value: vehiculo.fechaUltimoServicio == null
                          ? 'Sin registro'
                          : '${vehiculo.fechaUltimoServicio!.day.toString().padLeft(2, '0')}/${vehiculo.fechaUltimoServicio!.month.toString().padLeft(2, '0')}/${vehiculo.fechaUltimoServicio!.year}',
                      textColor: textColor,
                      mutedColor: mutedColor,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            NavCard(
              icon: Icons.report_problem_outlined,
              title: 'Reportar pendiente del vehículo',
              subtitle: vehiculo == null
                  ? 'Sin vehículo asignado'
                  : 'Falla mecánica, llanta o mantenimiento',
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
              onTap: vehiculo == null
                  ? null
                  : () async {
                      final reportado = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) =>
                              VehiclePendingScreen(vehiculoId: vehiculo.id),
                        ),
                      );
                      if (reportado == true) _refrescarPendientes(vehiculo.id);
                    },
            ),
            const SizedBox(height: 12),
            if (vehiculo == null)
              NavCard(
                icon: Icons.description_outlined,
                title: 'Documentos del vehículo',
                subtitle: 'Sin vehículo asignado',
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: null,
              )
            else
              FutureBuilder<List<VehiculoDocumentoResumen>>(
                future: _documentosFuture,
                builder: (context, docsSnapshot) {
                  final documentos = docsSnapshot.data;
                  final docsPorAtender = documentos
                      ?.where(
                        (d) =>
                            estadoDeVigencia(d.vigencia) !=
                            VehiculoDocumentoEstado.vigente,
                      )
                      .length;

                  return NavCard(
                    icon: Icons.description_outlined,
                    title: 'Documentos del vehículo',
                    subtitle: docsPorAtender == null
                        ? 'Cargando...'
                        : (docsPorAtender > 0
                              ? '$docsPorAtender por atender'
                              : 'Todo en regla'),
                    badgeColor: (docsPorAtender ?? 0) > 0
                        ? AppColors.error
                        : null,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              VehicleDocumentsScreen(vehiculo: vehiculo),
                        ),
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 12),
            if (vehiculo == null)
              NavCard(
                icon: Icons.assignment_late_outlined,
                title: 'Reportes',
                subtitle: 'Sin vehículo asignado',
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: null,
              )
            else
              FutureBuilder<List<VehiculoPendienteResumen>>(
                future: _pendientesFuture,
                builder: (context, pendSnapshot) {
                  final pendientes = pendSnapshot.data;
                  final abiertos = pendientes
                      ?.where((p) => p.fechaResolucion == null)
                      .length;

                  return NavCard(
                    icon: Icons.assignment_late_outlined,
                    title: 'Reportes',
                    subtitle: abiertos == null
                        ? 'Cargando...'
                        : (abiertos > 0
                              ? '$abiertos abierto${abiertos == 1 ? '' : 's'}'
                              : 'Sin pendientes abiertos'),
                    badgeColor: (abiertos ?? 0) > 0
                        ? AppColors.warning
                        : null,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              VehiclePendientesScreen(vehiculo: vehiculo),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
