/// One row from `notificacion-controller`'s `GET /notificaciones` (see
/// `NotificacionResponse` in auth-service's OpenAPI). `referenciaTipo`/
/// `referenciaId` presumably point back at whatever pedido/remisión caused
/// this notification, but the backend hasn't documented the concrete
/// `referenciaTipo` values it sends — so this app doesn't try to deep-link
/// off them yet, just shows the notification itself.
class Notificacion {
  final int id;
  final String tipo;
  final String titulo;
  final String mensaje;
  final bool leida;
  final DateTime? leidaEn;
  final String? referenciaTipo;
  final int? referenciaId;
  final DateTime creadoEn;

  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.leida,
    required this.leidaEn,
    required this.referenciaTipo,
    required this.referenciaId,
    required this.creadoEn,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id'] as int,
      tipo: json['tipo'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      mensaje: json['mensaje'] as String? ?? '',
      leida: json['leida'] as bool? ?? false,
      leidaEn: json['leidaEn'] == null ? null : DateTime.tryParse(json['leidaEn'] as String),
      referenciaTipo: json['referenciaTipo'] as String?,
      referenciaId: json['referenciaId'] as int?,
      creadoEn: DateTime.tryParse(json['creadoEn'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Notificacion copyWith({bool? leida, DateTime? leidaEn}) {
    return Notificacion(
      id: id,
      tipo: tipo,
      titulo: titulo,
      mensaje: mensaje,
      leida: leida ?? this.leida,
      leidaEn: leidaEn ?? this.leidaEn,
      referenciaTipo: referenciaTipo,
      referenciaId: referenciaId,
      creadoEn: creadoEn,
    );
  }
}
