import 'asesor.dart';

/// `AgendaActividad.tipoActividad` enum values, per `comercial-service`'s
/// `AgendaRequest` schema.
enum TipoActividad {
  llamada,
  whatsapp,
  seguimiento,
  cotizacion,
  visita,
  recordatorio;

  String get backendValue => name;

  static TipoActividad fromBackend(String? value) {
    for (final tipo in TipoActividad.values) {
      if (tipo.backendValue == value) return tipo;
    }
    return TipoActividad.seguimiento;
  }

  String get label {
    switch (this) {
      case TipoActividad.llamada:
        return 'Llamada';
      case TipoActividad.whatsapp:
        return 'WhatsApp';
      case TipoActividad.seguimiento:
        return 'Seguimiento';
      case TipoActividad.cotizacion:
        return 'Cotización';
      case TipoActividad.visita:
        return 'Visita';
      case TipoActividad.recordatorio:
        return 'Recordatorio';
    }
  }
}

/// Mirrors `AgendaResponse` from `comercial-service`.
class AgendaActividad {
  final int id;
  final int asesorId;
  final String asesorNombre;
  final int? clienteId;
  final String? clienteNombre;
  final int? obraId;
  final String? obraNombre;
  final int? cotizacionId;
  final int? pedidoId;
  final TipoActividad tipoActividad;
  final String fechaHora;
  final int? minutosRecordatorio;
  final String estatus;
  final String? observaciones;

  const AgendaActividad({
    required this.id,
    required this.asesorId,
    required this.asesorNombre,
    required this.clienteId,
    required this.clienteNombre,
    required this.obraId,
    required this.obraNombre,
    required this.cotizacionId,
    required this.pedidoId,
    required this.tipoActividad,
    required this.fechaHora,
    required this.minutosRecordatorio,
    required this.estatus,
    required this.observaciones,
  });

  factory AgendaActividad.fromJson(Map<String, dynamic> json) {
    return AgendaActividad(
      id: parseAsesorInt(json['id']),
      asesorId: parseAsesorInt(json['asesorId']),
      asesorNombre: json['asesorNombre'] as String? ?? '',
      clienteId: parseAsesorIntOrNull(json['clienteId']),
      clienteNombre: json['clienteNombre'] as String?,
      obraId: parseAsesorIntOrNull(json['obraId']),
      obraNombre: json['obraNombre'] as String?,
      cotizacionId: parseAsesorIntOrNull(json['cotizacionId']),
      pedidoId: parseAsesorIntOrNull(json['pedidoId']),
      tipoActividad: TipoActividad.fromBackend(json['tipoActividad'] as String?),
      fechaHora: json['fechaHora'] as String? ?? '',
      minutosRecordatorio: parseAsesorIntOrNull(json['minutosRecordatorio']),
      estatus: json['estatus'] as String? ?? 'pendiente',
      observaciones: json['observaciones'] as String?,
    );
  }
}

/// Mirrors `RutaDiariaResponse` from `GET /agenda/ruta-diaria`.
class RutaDiaria {
  final int totalActividades;
  final int actividadesCompletadas;
  final int actividadesPendientes;
  final List<AgendaActividad> actividades;

  const RutaDiaria({
    required this.totalActividades,
    required this.actividadesCompletadas,
    required this.actividadesPendientes,
    required this.actividades,
  });

  factory RutaDiaria.fromJson(Map<String, dynamic> json) {
    return RutaDiaria(
      totalActividades: parseAsesorInt(json['totalActividades']),
      actividadesCompletadas: parseAsesorInt(json['actividadesCompletadas']),
      actividadesPendientes: parseAsesorInt(json['actividadesPendientes']),
      actividades: (json['actividades'] as List<dynamic>? ?? const [])
          .map((e) => AgendaActividad.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
