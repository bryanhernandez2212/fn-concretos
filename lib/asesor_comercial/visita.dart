import 'asesor.dart';

/// Mirrors `VisitaResponse` from `comercial-service`'s `/visitas` endpoints.
class Visita {
  final int id;
  final int asesorId;
  final String asesorNombre;
  final int? obraId;
  final String? obraNombre;
  final int? clienteId;
  final String? clienteNombre;
  final String fechaVisita;
  final String? horaCheckin;
  final double? latitud;
  final double? longitud;
  final String? fotoEvidenciaUrl;
  final String? contactoNombre;
  final String? contactoTelefono;
  final double? volumenAproximado;
  final String? metodoCheckin;
  final String estatus;

  const Visita({
    required this.id,
    required this.asesorId,
    required this.asesorNombre,
    required this.obraId,
    required this.obraNombre,
    required this.clienteId,
    required this.clienteNombre,
    required this.fechaVisita,
    required this.horaCheckin,
    required this.latitud,
    required this.longitud,
    required this.fotoEvidenciaUrl,
    required this.contactoNombre,
    required this.contactoTelefono,
    required this.volumenAproximado,
    required this.metodoCheckin,
    required this.estatus,
  });

  factory Visita.fromJson(Map<String, dynamic> json) {
    return Visita(
      id: parseAsesorInt(json['id']),
      asesorId: parseAsesorInt(json['asesorId']),
      asesorNombre: json['asesorNombre'] as String? ?? '',
      obraId: parseAsesorIntOrNull(json['obraId']),
      obraNombre: json['obraNombre'] as String?,
      clienteId: parseAsesorIntOrNull(json['clienteId']),
      clienteNombre: json['clienteNombre'] as String?,
      fechaVisita: json['fechaVisita'] as String? ?? '',
      horaCheckin: json['horaCheckin'] as String?,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      fotoEvidenciaUrl: json['fotoEvidenciaUrl'] as String?,
      contactoNombre: json['contactoNombre'] as String?,
      contactoTelefono: json['contactoTelefono'] as String?,
      volumenAproximado: (json['volumenAproximado'] as num?)?.toDouble(),
      metodoCheckin: json['metodoCheckin'] as String?,
      estatus: json['estatus'] as String? ?? 'asignada',
    );
  }
}

/// Mirrors `ResumenVisitasResponse` from `GET /visitas/resumen-dia`.
class ResumenVisitas {
  final int visitasRealizadas;
  final int visitasMinimoRequerido;
  final bool cumpleMinimo;

  const ResumenVisitas({
    required this.visitasRealizadas,
    required this.visitasMinimoRequerido,
    required this.cumpleMinimo,
  });

  factory ResumenVisitas.fromJson(Map<String, dynamic> json) {
    return ResumenVisitas(
      visitasRealizadas: parseAsesorInt(json['visitasRealizadas']),
      visitasMinimoRequerido: parseAsesorInt(json['visitasMinimoRequerido']),
      cumpleMinimo: json['cumpleMinimo'] as bool? ?? false,
    );
  }
}
