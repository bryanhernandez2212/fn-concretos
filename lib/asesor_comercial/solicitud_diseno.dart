import 'asesor.dart';

/// Mirrors `SolicitudDisenoResponse` from `comercial-service`. This app only
/// creates requests and shows their status — resolving viabilidad is a
/// laboratorio-side action, not wired here.
class SolicitudDiseno {
  final int id;
  final int clienteId;
  final int? obraId;
  final String? productoSolicitado;
  final String? revenimiento;
  final String? tamanoAgregado;
  final String? caracteristicaEspecial;
  final String? fechaDeseada;
  final String? fechaLimiteRespuesta;
  final String estatus;
  final String? resultadoViabilidad;

  const SolicitudDiseno({
    required this.id,
    required this.clienteId,
    required this.obraId,
    required this.productoSolicitado,
    required this.revenimiento,
    required this.tamanoAgregado,
    required this.caracteristicaEspecial,
    required this.fechaDeseada,
    required this.fechaLimiteRespuesta,
    required this.estatus,
    required this.resultadoViabilidad,
  });

  factory SolicitudDiseno.fromJson(Map<String, dynamic> json) {
    return SolicitudDiseno(
      id: parseAsesorInt(json['id']),
      clienteId: parseAsesorInt(json['clienteId']),
      obraId: parseAsesorIntOrNull(json['obraId']),
      productoSolicitado: json['productoSolicitado'] as String?,
      revenimiento: json['revenimiento'] as String?,
      tamanoAgregado: json['tamanoAgregado'] as String?,
      caracteristicaEspecial: json['caracteristicaEspecial'] as String?,
      fechaDeseada: json['fechaDeseada'] as String?,
      fechaLimiteRespuesta: json['fechaLimiteRespuesta'] as String?,
      estatus: json['estatus'] as String? ?? 'pendiente',
      resultadoViabilidad: json['resultadoViabilidad'] as String?,
    );
  }
}
