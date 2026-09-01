int parseAsesorInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? parseAsesorIntOrNull(dynamic value) => value == null ? null : parseAsesorInt(value);

/// Mirrors `AsesorResponse` from `comercial-service`. Links to
/// [AuthService.usuarioId] (the `/auth/me` account id) via [usuarioId] — not
/// [AuthService.idEmpleado] — same distinction `OneSignalService.syncSession`
/// relies on elsewhere in this app.
class Asesor {
  final int id;
  final int usuarioId;
  final String nombre;
  final String tipo;
  final int? plantaId;
  final String estatus;

  const Asesor({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.tipo,
    required this.plantaId,
    required this.estatus,
  });

  factory Asesor.fromJson(Map<String, dynamic> json) {
    return Asesor(
      id: parseAsesorInt(json['id']),
      usuarioId: parseAsesorInt(json['usuarioId']),
      nombre: json['nombre'] as String? ?? '',
      tipo: json['tipo'] as String? ?? '',
      plantaId: parseAsesorIntOrNull(json['plantaId']),
      estatus: json['estatus'] as String? ?? '',
    );
  }
}
