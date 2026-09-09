/// Mirrors `VehiculoResponse` from the `operaciones` service
/// (`/sandbox/operaciones/v3/api-docs`) — just enough to show "mi vehículo"
/// and, via `conductorAsignadoId`, tell which one is this driver's own (see
/// `vehicle/vehiculo_service.dart`). There's no query param to filter
/// `GET /vehiculos` by conductor, so the filtering happens client-side —
/// same idiom as `AsignacionResumen.conductorId` in
/// `deliveries/entregas_service.dart`.
class VehiculoResumen {
  final int id;
  final String numeroUnidad;
  final String descripcion;
  final String grupo;
  final String estatus;
  final String marca;
  final String modelo;
  final String color;
  final String numeroSerieVin;
  final String placas;
  final String gpsInstalado;
  final bool camaraInstalada;
  final DateTime? fechaUltimoServicio;
  final int? conductorAsignadoId;
  final int? tipoVehiculoId;
  // The backend resolves the assigned 3D model straight onto the vehículo
  // response — `modelo3d-controller`'s own list/detail endpoints are for
  // populating the admin-side selector when assigning one, not something
  // this app calls for "mi vehículo" (see `vehiculo_service.dart`).
  final int? modelo3dId;
  final String? modelo3dNombre;
  final String? modelo3dUrl;

  const VehiculoResumen({
    required this.id,
    required this.numeroUnidad,
    required this.descripcion,
    required this.grupo,
    required this.estatus,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.numeroSerieVin,
    required this.placas,
    required this.gpsInstalado,
    required this.camaraInstalada,
    required this.fechaUltimoServicio,
    required this.conductorAsignadoId,
    required this.tipoVehiculoId,
    required this.modelo3dId,
    required this.modelo3dNombre,
    required this.modelo3dUrl,
  });

  factory VehiculoResumen.fromJson(Map<String, dynamic> json) {
    return VehiculoResumen(
      id: json['id'] as int,
      numeroUnidad: json['numeroUnidad'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      grupo: json['grupo'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
      marca: json['marca'] as String? ?? '',
      modelo: json['modelo'] as String? ?? '',
      color: json['color'] as String? ?? '',
      numeroSerieVin: json['numeroSerieVin'] as String? ?? '',
      placas: json['placas'] as String? ?? '',
      gpsInstalado: json['gpsInstalado'] as String? ?? '',
      camaraInstalada: json['camaraInstalada'] as bool? ?? false,
      fechaUltimoServicio: DateTime.tryParse(json['fechaUltimoServicio'] as String? ?? ''),
      conductorAsignadoId: json['conductorAsignadoId'] as int?,
      tipoVehiculoId: json['tipoVehiculoId'] as int?,
      modelo3dId: json['modelo3dId'] as int?,
      modelo3dNombre: json['modelo3dNombre'] as String?,
      modelo3dUrl: json['modelo3dUrl'] as String?,
    );
  }
}

/// Mirrors `Modelo3dResponse` — the reusable-by-tipo catalog entry, fetched
/// via `OperacionesService.modelosPorTipoVehiculo` only as a fallback for
/// when a vehículo hasn't been assigned a `modelo3dId` of its own yet (see
/// `vehiculo_service.dart`).
class Modelo3dResumen {
  final int id;
  final String nombre;
  final int? tipoVehiculoId;
  final String url;
  final String? descripcion;
  final String estatus;

  const Modelo3dResumen({
    required this.id,
    required this.nombre,
    required this.tipoVehiculoId,
    required this.url,
    required this.descripcion,
    required this.estatus,
  });

  bool get activo => estatus == 'activo';

  factory Modelo3dResumen.fromJson(Map<String, dynamic> json) {
    return Modelo3dResumen(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      tipoVehiculoId: json['tipoVehiculoId'] as int?,
      url: json['url'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      estatus: json['estatus'] as String? ?? '',
    );
  }
}

/// Mirrors `VehiculoDocumentoResponse` — read-only from this app (uploading
/// a new one needs `archivoUrl`, a pre-existing URL this app has no way to
/// produce, same blob-storage gap as `SignatureScreen`/`DeliveryPhotoScreen`
/// — see `vehicle/vehicle_documents_screen.dart`).
class VehiculoDocumentoResumen {
  final int id;
  final String tipoDocumento;
  final DateTime? vigencia;

  const VehiculoDocumentoResumen({
    required this.id,
    required this.tipoDocumento,
    required this.vigencia,
  });

  factory VehiculoDocumentoResumen.fromJson(Map<String, dynamic> json) {
    return VehiculoDocumentoResumen(
      id: json['id'] as int,
      tipoDocumento: json['tipoDocumento'] as String? ?? 'Documento',
      vigencia: DateTime.tryParse(json['vigencia'] as String? ?? ''),
    );
  }
}

/// The literal `estatus` values a mantenimiento can be in, per the
/// `PATCH /vehiculos/{vehiculoId}/mantenimientos/{id}/estatus` endpoint
/// description. `pendiente`/`enProceso` mean the vehicle is currently being
/// worked on; `concluido`/`conObservaciones` mean it's done.
const _mantenimientosActivos = {'pendiente', 'en_proceso'};

/// Mirrors `VehiculoMantenimientoResponse` — just enough to tell whether
/// the vehicle is currently under a mechanical/electrical service.
class VehiculoMantenimientoResumen {
  final int id;
  final String tipoSeguimiento;
  final String descripcionHallazgo;
  final String estatus;
  final DateTime? fechaServicio;

  const VehiculoMantenimientoResumen({
    required this.id,
    required this.tipoSeguimiento,
    required this.descripcionHallazgo,
    required this.estatus,
    required this.fechaServicio,
  });

  bool get activo => _mantenimientosActivos.contains(estatus);

  factory VehiculoMantenimientoResumen.fromJson(Map<String, dynamic> json) {
    return VehiculoMantenimientoResumen(
      id: json['id'] as int,
      tipoSeguimiento: json['tipoSeguimiento'] as String? ?? '',
      descripcionHallazgo: json['descripcionHallazgo'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
      fechaServicio: DateTime.tryParse(json['fechaServicio'] as String? ?? ''),
    );
  }
}

/// Mirrors `VehiculoPendienteResponse` — a pendiente this driver (or anyone
/// else) reported on the vehicle, real via
/// `OperacionesService.pendientesVehiculo` (see
/// `vehicle/vehicle_pendientes_screen.dart`).
class VehiculoPendienteResumen {
  final int id;
  final String tipoPendiente;
  final String descripcion;
  final String estatus;
  final DateTime? fechaDeteccion;
  final DateTime? fechaResolucion;
  final String? evidenciaApertura;
  final String? evidenciaCierre;

  const VehiculoPendienteResumen({
    required this.id,
    required this.tipoPendiente,
    required this.descripcion,
    required this.estatus,
    required this.fechaDeteccion,
    required this.fechaResolucion,
    required this.evidenciaApertura,
    required this.evidenciaCierre,
  });

  factory VehiculoPendienteResumen.fromJson(Map<String, dynamic> json) {
    return VehiculoPendienteResumen(
      id: json['id'] as int,
      tipoPendiente: json['tipoPendiente'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
      fechaDeteccion: DateTime.tryParse(json['fechaDeteccion'] as String? ?? ''),
      fechaResolucion: DateTime.tryParse(json['fechaResolucion'] as String? ?? ''),
      evidenciaApertura: json['evidenciaApertura'] as String?,
      evidenciaCierre: json['evidenciaCierre'] as String?,
    );
  }
}
