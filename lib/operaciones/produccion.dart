/// Mirrors `ProgramacionProduccionResponse` from the `operaciones` service
/// (`/sandbox/operaciones/v3/api-docs`) — just the fields
/// `deliveries/entregas_service.dart` needs to build today's delivery list.
class ProgramacionProduccion {
  final int id;
  final int pedidoId;
  final String horaArranque;
  final String estatus;

  const ProgramacionProduccion({
    required this.id,
    required this.pedidoId,
    required this.horaArranque,
    required this.estatus,
  });

  factory ProgramacionProduccion.fromJson(Map<String, dynamic> json) {
    return ProgramacionProduccion(
      id: json['id'] as int,
      pedidoId: json['pedidoId'] as int,
      horaArranque: json['horaArranque'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
    );
  }
}

/// Mirrors `AsignacionResponse` — just enough to tell whether the logged-in
/// conductor is the one assigned to a pedido (see
/// `deliveries/entregas_service.dart`).
class AsignacionResumen {
  final int pedidoId;
  final int? conductorId;

  const AsignacionResumen({required this.pedidoId, required this.conductorId});

  factory AsignacionResumen.fromJson(Map<String, dynamic> json) {
    return AsignacionResumen(
      pedidoId: json['pedidoId'] as int,
      conductorId: json['conductorId'] as int?,
    );
  }
}

/// Full `ProgramacionResponse` row, for read-only views (the asesor's
/// previa/programación card). Unlike [ProgramacionProduccion] it tolerates a
/// null `pedidoId`, which a "previa" row (tied to a cotización) can have.
class ProgramacionFila {
  final int id;
  final int? pedidoId;
  final int? cotizacionId;
  final int? plantaId;

  /// `yyyy-MM-dd`.
  final String? fechaProgramada;

  /// "HH:mm", or null when it wasn't captured.
  final String? horaArranque;
  final int? personalRequerido;

  /// Lowercase: `previa`, `programado`, `aprobado` or `cancelada`.
  final String estatus;

  const ProgramacionFila({
    required this.id,
    this.pedidoId,
    this.cotizacionId,
    this.plantaId,
    this.fechaProgramada,
    this.horaArranque,
    this.personalRequerido,
    required this.estatus,
  });

  factory ProgramacionFila.fromJson(Map<String, dynamic> json) {
    final hora = (json['horaArranque'] as String?)?.trim();
    return ProgramacionFila(
      id: (json['id'] as num).toInt(),
      pedidoId: (json['pedidoId'] as num?)?.toInt(),
      cotizacionId: (json['cotizacionId'] as num?)?.toInt(),
      plantaId: (json['plantaId'] as num?)?.toInt(),
      fechaProgramada: json['fechaProgramada'] as String?,
      horaArranque: hora == null || hora.isEmpty
          ? null
          : (hora.length < 5 ? hora : hora.substring(0, 5)),
      personalRequerido: (json['personalRequerido'] as num?)?.toInt(),
      estatus: (json['estatus'] as String? ?? '').toLowerCase(),
    );
  }
}
