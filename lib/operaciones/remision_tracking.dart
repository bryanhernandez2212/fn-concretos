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

  const RemisionResumen({
    required this.id,
    required this.folioRemision,
    required this.estatus,
    required this.conductorId,
    this.pedidoId,
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
      conductorId: json['conductorId'] == null ? null : _parseInt(json['conductorId']),
      pedidoId: json['pedidoId'] == null ? null : _parseInt(json['pedidoId']),
      horaCarga: DateTime.tryParse(json['horaCarga'] as String? ?? ''),
      horaSalida: DateTime.tryParse(json['horaSalida'] as String? ?? ''),
      horaLlegadaObra: DateTime.tryParse(json['horaLlegadaObra'] as String? ?? ''),
      horaEntrega: DateTime.tryParse(json['horaEntrega'] as String? ?? ''),
      metrosSolicitados: (json['metrosSolicitados'] as num?)?.toDouble(),
      metrosCargados: (json['metrosCargados'] as num?)?.toDouble(),
      metrosAcumuladosPedido: (json['metrosAcumuladosPedido'] as num?)?.toDouble(),
      metrosPendientesPedido: (json['metrosPendientesPedido'] as num?)?.toDouble(),
    );
  }
}

/// See `direccion/pedido.dart`'s identical helper — some Spring/Jackson
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

  const GpsPing({required this.latitud, required this.longitud, required this.timestampCaptura});

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
    final ultimaUbicacionJson = json['ultimaUbicacion'] as Map<String, dynamic>?;
    return RutaRemision(
      remisionId: json['remisionId'] as int,
      folioRemision: json['folioRemision'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
      ultimaUbicacion: ultimaUbicacionJson == null ? null : GpsPing.fromJson(ultimaUbicacionJson),
      historial: (json['historial'] as List<dynamic>?)
              ?.map((e) => GpsPing.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
