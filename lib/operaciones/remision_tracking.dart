/// Mirrors `RemisionResponse` from the `operaciones` service
/// (`/sandbox/operaciones/v3/api-docs`) — just the fields needed to list
/// which remisiones belong to a pedido, label each tracking card, and (via
/// `conductorId`) tell which one is this driver's own delivery (see
/// `deliveries/entregas_service.dart`).
class RemisionResumen {
  final int id;
  final String folioRemision;
  final String estatus;
  final int? conductorId;

  /// The pedido this remisión belongs to — not previously mapped since
  /// nothing needed it, but `RutasActivasScreen`'s fleet-wide view needs it
  /// to resolve each truck's destino (obra lat/lng) for its ETA/progress
  /// overlay, since unlike `deliveries/remision.dart`'s driver-facing
  /// `Remision` model this one was never built with a destino already
  /// resolved.
  final int? pedidoId;

  /// The olla/bomba units carrying this remisión — used to look up which
  /// medium tracks it (`VehiculoResumen.origenGps`, see
  /// `operaciones/rastreo_gps.dart`) and sent along with each GPS ping.
  final int? vehiculoOllaId;
  final int? vehiculoBombaId;

  /// Bombeo fields — only meaningful when [vehiculoBombaId] is set.
  /// `conductorBombaId` is the Operador de Bomba's idEmpleado (what
  /// `EntregasService` lists by for that role); `ordenTrabajoBombeoId` is
  /// the turno de bombeo dispatch linked this remisión to when creating it
  /// (the app can't change it). `horaInicioBombeo` is stamped by the
  /// backend on the `descargando` hito; `horaEntrega` doubles as the end of
  /// bombeo. `metrosBombeados` is what the operator typed on `entregado`.
  final String? vehiculoBombaNumeroUnidad;
  final int? conductorBombaId;
  final int? ordenTrabajoBombeoId;
  final DateTime? horaInicioBombeo;
  final double? metrosBombeados;

  /// Timestamps the backend stamps as the remisión reaches each hito (not
  /// sent by the client — `OperacionesService.avanzarHito` only sends the
  /// `evento`). Null until that hito has actually happened.
  final DateTime? horaCarga;
  final DateTime? horaSalida;
  final DateTime? horaLlegadaObra;
  final DateTime? horaEntrega;

  /// This remisión's own volume — how much *this specific* truck/olla is
  /// carrying, not the pedido's total (a pedido like "40 m³" can be split
  /// across several remisiones, e.g. 4 trucks of 10 m³ each). `metrosCargados`
  /// is set once actually loaded at planta; `metrosSolicitados` is the plan
  /// before that. `metrosAcumuladosPedido`/`metrosPendientesPedido` track the
  /// whole pedido's running total as of this remisión, for context (see
  /// `deliveries/entregas_service.dart`).
  final double? metrosSolicitados;
  final double? metrosCargados;
  final double? metrosAcumuladosPedido;
  final double? metrosPendientesPedido;

  /// A rented-pumping remisión: a pluma/bomba pumping concrete that never
  /// left our planta, with no olla of ours assigned. It never passes through
  /// planta, so its hito sequence skips `cargando_planta` (same rule as the
  /// web, fnconcretos-front PR #185). "Olla + Pluma" is NOT solo bomba.
  bool get esSoloBomba => vehiculoOllaId == null && vehiculoBombaId != null;

  /// This remisión's own m³: `metrosCargados` once actually loaded, else the
  /// planned `metrosSolicitados`. The web always sends `metrosCargados` on
  /// create (as 0 when left blank, e.g. on a solo-bomba remisión), so a 0
  /// counts as "not loaded" rather than as the volume.
  double? get volumen {
    final cargados = metrosCargados;
    if (cargados != null && cargados > 0) return cargados;
    return metrosSolicitados ?? cargados;
  }

  const RemisionResumen({
    required this.id,
    required this.folioRemision,
    required this.estatus,
    required this.conductorId,
    this.pedidoId,
    this.vehiculoOllaId,
    this.vehiculoBombaId,
    this.vehiculoBombaNumeroUnidad,
    this.conductorBombaId,
    this.ordenTrabajoBombeoId,
    this.horaInicioBombeo,
    this.metrosBombeados,
    this.horaCarga,
    this.horaSalida,
    this.horaLlegadaObra,
    this.horaEntrega,
    this.metrosSolicitados,
    this.metrosCargados,
    this.metrosAcumuladosPedido,
    this.metrosPendientesPedido,
  });

  factory RemisionResumen.fromJson(Map<String, dynamic> json) {
    return RemisionResumen(
      id: _parseInt(json['id']),
      folioRemision: json['folioRemision'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
      conductorId: json['conductorId'] == null
          ? null
          : _parseInt(json['conductorId']),
      pedidoId: json['pedidoId'] == null ? null : _parseInt(json['pedidoId']),
      vehiculoOllaId: json['vehiculoOllaId'] == null
          ? null
          : _parseInt(json['vehiculoOllaId']),
      vehiculoBombaId: json['vehiculoBombaId'] == null
          ? null
          : _parseInt(json['vehiculoBombaId']),
      vehiculoBombaNumeroUnidad: json['vehiculoBombaNumeroUnidad'] as String?,
      conductorBombaId: json['conductorBombaId'] == null
          ? null
          : _parseInt(json['conductorBombaId']),
      ordenTrabajoBombeoId: json['ordenTrabajoBombeoId'] == null
          ? null
          : _parseInt(json['ordenTrabajoBombeoId']),
      horaInicioBombeo: DateTime.tryParse(
        json['horaInicioBombeo'] as String? ?? '',
      ),
      metrosBombeados: (json['metrosBombeados'] as num?)?.toDouble(),
      horaCarga: DateTime.tryParse(json['horaCarga'] as String? ?? ''),
      horaSalida: DateTime.tryParse(json['horaSalida'] as String? ?? ''),
      horaLlegadaObra: DateTime.tryParse(
        json['horaLlegadaObra'] as String? ?? '',
      ),
      horaEntrega: DateTime.tryParse(json['horaEntrega'] as String? ?? ''),
      metrosSolicitados: (json['metrosSolicitados'] as num?)?.toDouble(),
      metrosCargados: (json['metrosCargados'] as num?)?.toDouble(),
      metrosAcumuladosPedido: (json['metrosAcumuladosPedido'] as num?)
          ?.toDouble(),
      metrosPendientesPedido: (json['metrosPendientesPedido'] as num?)
          ?.toDouble(),
    );
  }
}

/// See `comercial/pedido.dart`'s identical helper — some Spring/Jackson
/// setups serialize `Long` fields as JSON strings, and this schema doesn't
/// mark `id`/`conductorId` as required either.
int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Mirrors `GpsPingResponse` — one position report from the olla/bomba en
/// route to the obra.
class GpsPing {
  final double latitud;
  final double longitud;
  final String? timestampCaptura;

  const GpsPing({
    required this.latitud,
    required this.longitud,
    required this.timestampCaptura,
  });

  factory GpsPing.fromJson(Map<String, dynamic> json) {
    return GpsPing(
      latitud: (json['latitud'] as num?)?.toDouble() ?? 0,
      longitud: (json['longitud'] as num?)?.toDouble() ?? 0,
      timestampCaptura: json['timestampCaptura'] as String?,
    );
  }
}

/// Mirrors `RutaRemisionResponse` — the full recorrido of a remisión:
/// current position plus position history, as seen by
/// `GET /remisiones/{id}/ruta`.
class RutaRemision {
  final int remisionId;
  final String folioRemision;
  final String estatus;
  final GpsPing? ultimaUbicacion;
  final List<GpsPing> historial;

  const RutaRemision({
    required this.remisionId,
    required this.folioRemision,
    required this.estatus,
    required this.ultimaUbicacion,
    required this.historial,
  });

  factory RutaRemision.fromJson(Map<String, dynamic> json) {
    final ultimaUbicacionJson =
        json['ultimaUbicacion'] as Map<String, dynamic>?;
    return RutaRemision(
      remisionId: json['remisionId'] as int,
      folioRemision: json['folioRemision'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
      ultimaUbicacion: ultimaUbicacionJson == null
          ? null
          : GpsPing.fromJson(ultimaUbicacionJson),
      historial:
          (json['historial'] as List<dynamic>?)
              ?.map((e) => GpsPing.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
