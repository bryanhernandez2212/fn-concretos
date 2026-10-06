int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Mirrors `PresignedUploadResponse` from `operaciones-service`
/// (`/sandbox/operaciones/v3/api-docs`) — returned by
/// `POST /evidencias/presigned-url`. [uploadUrl] is a presigned `PUT`
/// target the app uploads the file bytes to directly (bypassing the
/// backend entirely); [publicUrl] is what gets saved back onto whichever
/// business resource needs it (e.g. `FirmaRequest.firmaDigitalUrl`).
class PresignedUploadResponse {
  final String uploadUrl;
  final String publicUrl;
  final String key;
  final int? expiraEnMinutos;

  const PresignedUploadResponse({
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
    required this.expiraEnMinutos,
  });

  factory PresignedUploadResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUploadResponse(
      uploadUrl: json['uploadUrl'] as String? ?? '',
      publicUrl: json['publicUrl'] as String? ?? '',
      key: json['key'] as String? ?? '',
      expiraEnMinutos: json['expiraEnMinutos'] == null ? null : _asInt(json['expiraEnMinutos']),
    );
  }
}

/// Mirrors `FirmaResponse` — the `RemisionFirma` row created by
/// `POST /remisiones/{id}/firma` (also listable via the `GET` of the same
/// path, not yet consumed by this app).
class FirmaResponse {
  final int id;
  final int remisionId;
  final int operadorId;
  final String firmaDigitalUrl;
  final String? fechaHoraFirma;
  final String? evidenciaUrl;
  final String? comentarios;

  const FirmaResponse({
    required this.id,
    required this.remisionId,
    required this.operadorId,
    required this.firmaDigitalUrl,
    required this.fechaHoraFirma,
    required this.evidenciaUrl,
    required this.comentarios,
  });

  factory FirmaResponse.fromJson(Map<String, dynamic> json) {
    return FirmaResponse(
      id: _asInt(json['id']),
      remisionId: _asInt(json['remisionId']),
      operadorId: _asInt(json['operadorId']),
      firmaDigitalUrl: json['firmaDigitalUrl'] as String? ?? '',
      fechaHoraFirma: json['fechaHoraFirma'] as String?,
      evidenciaUrl: json['evidenciaUrl'] as String?,
      comentarios: json['comentarios'] as String?,
    );
  }
}

/// Mirrors `ArchivoResponse` — the `RemisionArchivo` row created by
/// `POST /remisiones/{id}/archivos` (also listable via the `GET` of the
/// same path).
class ArchivoResponse {
  final int id;
  final int remisionId;
  final String tipoArchivo;
  final String archivoUrl;
  final int? cargadoPor;
  final String? fechaCarga;

  const ArchivoResponse({
    required this.id,
    required this.remisionId,
    required this.tipoArchivo,
    required this.archivoUrl,
    required this.cargadoPor,
    required this.fechaCarga,
  });

  factory ArchivoResponse.fromJson(Map<String, dynamic> json) {
    return ArchivoResponse(
      id: _asInt(json['id']),
      remisionId: _asInt(json['remisionId']),
      tipoArchivo: json['tipoArchivo'] as String? ?? '',
      archivoUrl: json['archivoUrl'] as String? ?? '',
      cargadoPor: json['cargadoPor'] == null ? null : _asInt(json['cargadoPor']),
      fechaCarga: json['fechaCarga'] as String?,
    );
  }
}
