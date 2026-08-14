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
