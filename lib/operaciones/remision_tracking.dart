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

  /// Timestamps the backend stamps as the remisión reaches each hito (not
  /// sent by the client — `OperacionesService.avanzarHito` only sends the
  /// `evento`). Null until that hito has actually happened.
  final DateTime? horaCarga;
  final DateTime? horaSalida;
  final DateTime? horaLlegadaObra;
  final DateTime? horaEntrega;

  const RemisionResumen({
    required this.id,
    required this.folioRemision,
    required this.estatus,
    required this.conductorId,
    this.horaCarga,
    this.horaSalida,
    this.horaLlegadaObra,
    this.horaEntrega,
  });

  factory RemisionResumen.fromJson(Map<String, dynamic> json) {
    return RemisionResumen(
      id: json['id'] as int,
      folioRemision: json['folioRemision'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
      conductorId: json['conductorId'] as int?,
      horaCarga: DateTime.tryParse(json['horaCarga'] as String? ?? ''),
      horaSalida: DateTime.tryParse(json['horaSalida'] as String? ?? ''),
      horaLlegadaObra: DateTime.tryParse(json['horaLlegadaObra'] as String? ?? ''),
      horaEntrega: DateTime.tryParse(json['horaEntrega'] as String? ?? ''),
    );
  }
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
