import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../administracion/administracion_service.dart';
import '../catalogo/catalogo_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/rastreo_gps.dart';
import '../operaciones/vehiculo.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/rastreo_info_card.dart';
import 'vehicle.dart';
import 'vehicle_documents_screen.dart';
import 'vehicle_pendientes_screen.dart';
import 'vehicle_pending_screen.dart';
import 'vehicle_reportes_widgets.dart';
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

  late final Future<String?> _modelo3dUrlFuture = _vehiculoFuture.then(
    (vehiculo) =>
        vehiculo == null ? null : VehiculoService.modelo3dUrlPara(vehiculo),
  );

  // tipoVehiculoId/plantaAsignadaId/conductorAsignadoId come back as bare
  // ids; each is resolved to a name best-effort — a failed lookup just shows
  // the raw id instead, not a broken screen.
  late final Future<_NombresVehiculo> _nombresFuture = _vehiculoFuture.then((
    vehiculo,
  ) async {
    if (vehiculo == null) return const _NombresVehiculo();
    Future<String?> seguro(Future<String?> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    final resultados = await Future.wait([
      seguro(
        () async => vehiculo.tipoVehiculoId == null
            ? null
            : (await CatalogoService.tiposVehiculo())[vehiculo.tipoVehiculoId],
      ),
      seguro(() async {
        if (vehiculo.plantaAsignadaId == null) return null;
        final plantas = await CatalogoService.plantas();
        for (final p in plantas) {
          if (p.id == vehiculo.plantaAsignadaId) return p.nombre;
        }
        return null;
      }),
      seguro(
        () async => vehiculo.conductorAsignadoId == null
            ? null
            : (await AdministracionService.obtenerEmpleado(
                vehiculo.conductorAsignadoId!,
              )).nombreCompleto,
      ),
    ]);
    return _NombresVehiculo(
      tipo: resultados[0],
      planta: resultados[1],
      conductor: resultados[2],
    );
  });

  bool _verReportes = false;

  void _refrescarPendientes(int vehiculoId) {
    setState(() {
      _pendientesFuture = OperacionesService.pendientesVehiculo(vehiculoId);
    });
  }

  Future<void> _reportar(VehiculoResumen vehiculo, TipoPendiente? tipo) async {
    final reportado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VehiclePendingScreen(
          vehiculoId: vehiculo.id,
          unidad: vehiculo.numeroUnidad,
          placas: vehiculo.placas,
          tipoInicial: tipo,
        ),
      ),
    );
    if (reportado == true) _refrescarPendientes(vehiculo.id);
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
                const NotificationBellButton(),
              ],
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<VehiculoPendienteResumen>>(
              future: _pendientesFuture,
              builder: (context, pendSnap) =>
                  FutureBuilder<List<VehiculoDocumentoResumen>>(
                    future: _documentosFuture,
                    builder: (context, docsSnap) => VehicleTabSelector(
                      verReportes: _verReportes,
                      reportesBadge:
                          _abiertos(pendSnap.data).length +
                          _docsPorAtender(docsSnap.data).length,
                      onChanged: (v) => setState(() => _verReportes = v),
                    ),
                  ),
            ),
            const SizedBox(height: 18),
            // Kept mounted while hidden (maintainState) so whichever
            // DetailSections the driver had expanded survive a round trip
            // to the Reportes tab.
            Visibility(
              visible: !_verReportes,
              maintainState: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  if (vehiculo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: RastreoInfoCard(
                        origen: OrigenGpsInfo.parse(vehiculo.origenGps),
                      ),
                    ),
                  if (vehiculo != null)
                    FutureBuilder<String?>(
                      future: _modelo3dUrlFuture,
                      builder: (context, modeloSnapshot) {
                        final modeloUrl = modeloSnapshot.data;
                        // Best-effort: no modelo3d assigned to this vehículo/tipo
                        // yet just means this card doesn't render, not an error —
                        // same idiom as VisitaDetailScreen's obra lookup.
                        if (modeloUrl == null || modeloUrl.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 240,
                              decoration: BoxDecoration(
                                color: cardColor,
                                border: Border.all(color: borderColor),
                              ),
                              child: ModelViewer(
                                backgroundColor: Colors.transparent,
                                src: modeloUrl,
                                alt: 'Modelo 3D del vehículo',
                                autoRotate: true,
                                cameraControls: true,
                              ),
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
                    FutureBuilder<_NombresVehiculo>(
                      future: _nombresFuture,
                      builder: (context, nombresSnapshot) => _Detalles(
                        vehiculo: vehiculo,
                        nombres: nombresSnapshot.data,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                    ),
                ],
              ),
            ),
            if (_verReportes)
              _ReportesTab(
                vehiculo: vehiculo,
                pendientesFuture: _pendientesFuture,
                documentosFuture: _documentosFuture,
                onReportar: (tipo) => _reportar(vehiculo!, tipo),
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
          ],
        );
      },
    );
  }
}

List<VehiculoPendienteResumen> _abiertos(List<VehiculoPendienteResumen>? p) =>
    p?.where((e) => e.fechaResolucion == null).toList() ?? const [];

List<VehiculoDocumentoResumen> _docsPorAtender(
  List<VehiculoDocumentoResumen>? d,
) =>
    d
        ?.where(
          (e) =>
              estadoDeVigencia(e.vigencia) != VehiculoDocumentoEstado.vigente,
        )
        .toList() ??
    const [];

/// "Reportes" tab: the three entry points — report a pendiente, the
/// vehicle's documents, and the list of reports already made.
class _ReportesTab extends StatelessWidget {
  final VehiculoResumen? vehiculo;
  final Future<List<VehiculoPendienteResumen>> pendientesFuture;
  final Future<List<VehiculoDocumentoResumen>> documentosFuture;
  final ValueChanged<TipoPendiente?> onReportar;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _ReportesTab({
    required this.vehiculo,
    required this.pendientesFuture,
    required this.documentosFuture,
    required this.onReportar,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final vehiculo = this.vehiculo;

    NavCard card({
      required IconData icon,
      required String title,
      required String subtitle,
      Color? badgeColor,
      VoidCallback? onTap,
    }) => NavCard(
      icon: icon,
      title: title,
      subtitle: vehiculo == null ? 'Sin vehículo asignado' : subtitle,
      badgeColor: badgeColor,
      cardColor: cardColor,
      borderColor: borderColor,
      textColor: textColor,
      mutedColor: mutedColor,
      onTap: vehiculo == null ? null : onTap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          icon: Icons.report_problem_outlined,
          title: 'Reportar pendiente del vehículo',
          subtitle: 'Falla mecánica, llanta o mantenimiento',
          onTap: () => onReportar(null),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<VehiculoDocumentoResumen>>(
          future: documentosFuture,
          builder: (context, docsSnap) {
            final porAtender = docsSnap.hasData
                ? _docsPorAtender(docsSnap.data).length
                : null;
            return card(
              icon: Icons.description_outlined,
              title: 'Documentos del vehículo',
              subtitle: porAtender == null
                  ? 'Cargando...'
                  : (porAtender > 0
                        ? '$porAtender por atender'
                        : 'Todo en regla'),
              badgeColor: (porAtender ?? 0) > 0 ? AppColors.error : null,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      VehicleDocumentsScreen(vehiculo: vehiculo!),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<VehiculoPendienteResumen>>(
          future: pendientesFuture,
          builder: (context, pendSnap) {
            final abiertos = pendSnap.hasData
                ? _abiertos(pendSnap.data).length
                : null;
            return card(
              icon: Icons.assignment_late_outlined,
              title: 'Reportes',
              subtitle: abiertos == null
                  ? 'Cargando...'
                  : (abiertos > 0
                        ? '$abiertos abierto${abiertos == 1 ? '' : 's'}'
                        : 'Sin pendientes abiertos'),
              badgeColor: (abiertos ?? 0) > 0 ? AppColors.warning : null,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      VehiclePendientesScreen(vehiculo: vehiculo!),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NombresVehiculo {
  final String? tipo;
  final String? planta;
  final String? conductor;

  const _NombresVehiculo({this.tipo, this.planta, this.conductor});
}

/// Every field of `VehiculoResponse`, grouped into sections.
class _Detalles extends StatelessWidget {
  final VehiculoResumen vehiculo;
  final _NombresVehiculo? nombres;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _Detalles({
    required this.vehiculo,
    required this.nombres,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  /// Shows the resolved name when there is one, otherwise the raw id (or
  /// "Cargando..." while the lookup is still in flight).
  String _nombreOId(String? nombre, int? id) {
    if (id == null) return 'Sin asignar';
    if (nombre != null && nombre.isNotEmpty) return nombre;
    return nombres == null ? 'Cargando...' : 'ID $id';
  }

  @override
  Widget build(BuildContext context) {
    DetailRow fila(
      IconData icon,
      String label,
      String value, {
      bool isLast = false,
    }) => DetailRow(
      icon: icon,
      label: label,
      value: value,
      textColor: textColor,
      mutedColor: mutedColor,
      isLast: isLast,
    );

    DetailSection seccion(
      IconData icon,
      String title,
      List<String> resumen,
      List<DetailRow> rows,
    ) => DetailSection(
      icon: icon,
      title: title,
      resumen: resumen.where((r) => r.isNotEmpty).join(' · '),
      rows: rows,
      cardColor: cardColor,
      borderColor: borderColor,
      textColor: textColor,
      mutedColor: mutedColor,
    );

    final capacidad = vehiculo.capacidadM3;

    return Column(
      children: [
        seccion(
          Icons.badge_outlined,
          'Identificación',
          [vehiculo.numeroUnidad, etiquetaValorVehiculo(vehiculo.estatus)],
          [
            fila(Icons.numbers, 'Número de unidad', vehiculo.numeroUnidad),
            fila(
              Icons.local_shipping_outlined,
              'Tipo de vehículo',
              _nombreOId(nombres?.tipo, vehiculo.tipoVehiculoId),
            ),
            fila(
              Icons.description_outlined,
              'Descripción',
              vehiculo.descripcion,
            ),
            fila(Icons.category_outlined, 'Grupo', vehiculo.grupo),
            fila(
              Icons.toggle_on_outlined,
              'Estatus',
              etiquetaValorVehiculo(vehiculo.estatus),
              isLast: true,
            ),
          ],
        ),
        seccion(
          Icons.directions_car_outlined,
          'Especificaciones',
          ['${vehiculo.marca} ${vehiculo.modelo}'.trim(), vehiculo.placas],
          [
            fila(Icons.directions_car_outlined, 'Marca', vehiculo.marca),
            fila(Icons.event_outlined, 'Modelo', vehiculo.modelo),
            fila(Icons.palette_outlined, 'Color', vehiculo.color),
            fila(Icons.badge_outlined, 'Placas', vehiculo.placas),
            fila(Icons.pin_outlined, 'VIN', vehiculo.numeroSerieVin),
            fila(
              Icons.water_drop_outlined,
              'Capacidad',
              capacidad == null
                  ? 'No aplica'
                  : '${capacidad % 1 == 0 ? capacidad.toInt() : capacidad} m³',
              isLast: true,
            ),
          ],
        ),
        seccion(
          Icons.assignment_ind_outlined,
          'Asignación',
          [
            if (nombres?.planta != null) nombres!.planta!,
            if (nombres?.conductor != null) nombres!.conductor!,
          ],
          [
            fila(
              Icons.factory_outlined,
              'Planta asignada',
              _nombreOId(nombres?.planta, vehiculo.plantaAsignadaId),
            ),
            fila(
              Icons.person_outline,
              'Conductor asignado',
              _nombreOId(nombres?.conductor, vehiculo.conductorAsignadoId),
              isLast: true,
            ),
          ],
        ),
        seccion(
          Icons.settings_input_antenna,
          'Equipamiento',
          [
            if (etiquetaValorVehiculo(vehiculo.origenGps).isNotEmpty)
              'GPS: ${etiquetaValorVehiculo(vehiculo.origenGps)}',
            vehiculo.camaraInstalada ? 'Con cámara' : 'Sin cámara',
          ],
          [
            fila(
              Icons.gps_fixed,
              'GPS',
              etiquetaValorVehiculo(vehiculo.gpsInstalado),
            ),
            fila(
              Icons.satellite_alt_outlined,
              'Origen GPS',
              etiquetaValorVehiculo(vehiculo.origenGps),
            ),
            fila(
              Icons.sensors_outlined,
              'ID Samsara',
              vehiculo.samsaraVehiculoId ?? 'Sin vincular',
            ),
            fila(
              Icons.videocam_outlined,
              'Cámara instalada',
              vehiculo.camaraInstalada ? 'Sí' : 'No',
            ),
            fila(
              Icons.view_in_ar_outlined,
              'Modelo 3D',
              vehiculo.modelo3dNombre ?? 'Sin asignar',
              isLast: true,
            ),
          ],
        ),
        seccion(
          Icons.history,
          'Registro',
          [
            'Último servicio: ${formatoFechaVehiculo(vehiculo.fechaUltimoServicio)}',
          ],
          [
            fila(
              Icons.build_circle_outlined,
              'Último servicio',
              formatoFechaVehiculo(vehiculo.fechaUltimoServicio),
            ),
            fila(
              Icons.calendar_today_outlined,
              'Fecha de alta',
              formatoFechaVehiculo(vehiculo.createdAt, conHora: true),
            ),
            fila(Icons.tag, 'ID interno', '${vehiculo.id}', isLast: true),
          ],
        ),
      ],
    );
  }
}
