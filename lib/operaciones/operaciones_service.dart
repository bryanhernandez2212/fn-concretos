import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config.dart';
import 'evidencia.dart';
import 'produccion.dart';
import 'remision_tracking.dart';
import 'vehiculo.dart';

/// Permission required by `POST /remisiones/{id}/gps` and
/// `PATCH /remisiones/{id}/hitos` — held by field-operator roles, checked
/// before `RouteNavigationScreen` bothers posting a position.
const permisoOperarRemisiones = 'remisiones.operar';

/// Permission required by `POST /vehiculos/{vehiculoId}/pendientes` — held
/// by field-operator roles, checked before `VehiclePendingScreen` lets the
/// driver submit.
const permisoReportarPendienteVehiculo = 'vehiculos.reportar_pendiente';

/// Talks to the real fnconcretos `operaciones` sandbox (see its
/// `/v3/api-docs`) — remisiones y su rastreo GPS. Reuses
/// [AuthService.authHeaders] for the bearer token; this app has no
/// state-management package, so results are returned directly rather than
/// cached anywhere.
class OperacionesService {
  static const _baseUrl = ApiConfig.operaciones;
  // Requests had no timeout at all, so a flaky connection (common in the
  // field, e.g. uploading evidencia from a job site) could hang seemingly
  // forever with just a spinner instead of failing predictably so the
  // driver could retry.
  static const _timeout = Duration(seconds: 20);

  static Future<List<RemisionResumen>> remisionesPorPedido(int pedidoId) async {
    final data = await _get('/remisiones?pedidoId=$pedidoId');
    return (data as List<dynamic>)
        .map((e) => RemisionResumen.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<RutaRemision> rutaRemision(int remisionId) async {
    final data = await _get('/remisiones/$remisionId/ruta');
    return RutaRemision.fromJson(data as Map<String, dynamic>);
  }

  /// Every remisión currently out of the plant and not yet finished, across
  /// all pedidos — for Dirección's consolidated "todas las rutas" map.
  /// `GET /remisiones` takes no filter at all here (both `pedidoId` and
  /// `estatus` are optional per the OpenAPI schema, same as the unfiltered
  /// fleet-wide [vehiculos] call below), so this fetches everything and
  /// narrows client-side to the statuses that mean "on the road right now".
  static Future<List<RemisionResumen>> remisionesEnRuta() async {
    const enRuta = {
      'salio_planta',
      'en_camino',
      'proximo_llegar',
      'en_obra',
      'descargando',
    };
    final data = await _get('/remisiones');
    return (data as List<dynamic>)
        .map((e) => RemisionResumen.fromJson(e as Map<String, dynamic>))
        .where((r) => enRuta.contains(r.estatus))
        .toList();
  }

  /// `fecha` is `yyyy-MM-dd`. Plant-wide — not scoped to any one conductor —
  /// so callers must cross-reference [asignacionesPorPedido] to know which
  /// of these are actually theirs (see `deliveries/entregas_service.dart`).
  static Future<List<ProgramacionProduccion>> programacionDelDia(
    String fecha,
  ) async {
    final data = await _get('/programacion-produccion?fecha=$fecha');
    return (data as List<dynamic>)
        .map((e) => ProgramacionProduccion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<AsignacionResumen>> asignacionesPorPedido(
    int pedidoId,
  ) async {
    final data = await _get('/asignaciones?pedidoId=$pedidoId');
    return (data as List<dynamic>)
        .map((e) => AsignacionResumen.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Reports the olla/bomba's current position while en route. Requires
  /// [permisoOperarRemisiones].
  static Future<void> enviarPosicion(
    int remisionId, {
    required double latitud,
    required double longitud,
  }) {
    return _post('/remisiones/$remisionId/gps', {
      'latitud': latitud,
      'longitud': longitud,
    });
  }

  /// Full remisión detail — `estatus` plus the `hora*` hito timestamps
  /// `DeliveryDetailScreen` displays. Reuses [RemisionResumen] rather than a
  /// new DTO for the RemisionResponse fields still unused here (resistencia,
  /// revenimiento, metrosCargados, etc).
  static Future<RemisionResumen> remisionDetalle(int id) async {
    final data = await _get('/remisiones/$id');
    debugPrint('OperacionesService.remisionDetalle raw: ${jsonEncode(data)}'); // TEMP debug
    return RemisionResumen.fromJson(data as Map<String, dynamic>);
  }

  /// Advances a remisión to its next hito (`evento`, one of
  /// [HitoEntrega.backendValue]). Requires [permisoOperarRemisiones]. Returns
  /// the updated remisión from the response — the source of truth (new
  /// `estatus` and whichever `hora*` timestamp the backend just stamped),
  /// not an optimistic local guess.
  static Future<RemisionResumen> avanzarHito(
    int remisionId,
    String evento,
  ) async {
    final data = await _patch('/remisiones/$remisionId/hitos', {
      'evento': evento,
    });
    debugPrint('OperacionesService.avanzarHito raw: ${jsonEncode(data)}'); // TEMP debug
    return RemisionResumen.fromJson(data as Map<String, dynamic>);
  }

  /// Registers a "prueba de concreto fresco" (slump/temperature/unit-mass
  /// field test) against a remisión. `fechaPrueba`/`horaPrueba` are stamped
  /// from the moment the test is submitted — this is a field test performed
  /// at delivery time, not something scheduled ahead. Requires
  /// [permisoOperarRemisiones].
  static Future<void> registrarPruebaConcreto({
    required int remisionId,
    int? pedidoId,
    int? clienteId,
    int? obraId,
    required String revenimiento,
    required double masaUnitaria,
    required double temperatura,
    required double rendimiento,
    String? observaciones,
  }) {
    final ahora = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final fechaPrueba =
        '${ahora.year.toString().padLeft(4, '0')}-${two(ahora.month)}-${two(ahora.day)}';
    final horaPrueba =
        '${two(ahora.hour)}:${two(ahora.minute)}:${two(ahora.second)}';

    return _post('/pruebas-concreto-fresco', {
      'remisionId': remisionId,
      if (pedidoId != null) 'pedidoId': pedidoId,
      if (clienteId != null) 'clienteId': clienteId,
      if (obraId != null) 'obraId': obraId,
      'revenimiento': revenimiento,
      'masaUnitaria': masaUnitaria,
      'temperatura': temperatura,
      'rendimiento': rendimiento,
      if (observaciones != null && observaciones.isNotEmpty)
        'observaciones': observaciones,
      'fechaPrueba': fechaPrueba,
      'horaPrueba': horaPrueba,
    });
  }

  /// Requests a presigned upload URL for `carpeta`/`nombreArchivo`. The app
  /// then `PUT`s the file bytes directly to the returned `uploadUrl` (see
  /// [subirArchivoPresignado]) and keeps `publicUrl` to save back onto
  /// whichever business resource needs it (e.g. [registrarFirma]'s
  /// `firmaDigitalUrl`).
  static Future<PresignedUploadResponse> presignedUploadUrl({
    required String carpeta,
    required String nombreArchivo,
    required String contentType,
  }) async {
    final data = await _post('/evidencias/presigned-url', {
      'carpeta': carpeta,
      'nombreArchivo': nombreArchivo,
      'contentType': contentType,
    });
    return PresignedUploadResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Uploads raw bytes directly to a presigned URL from
  /// [presignedUploadUrl] — this goes straight to storage, not through
  /// operaciones-service, so it deliberately skips [AuthService.authHeaders]
  /// and sends only the `Content-Type` the presigned URL was issued for.
  static Future<void> subirArchivoPresignado(
    String uploadUrl,
    List<int> bytes,
    String contentType,
  ) async {
    final http.Response response;
    try {
      response = await http
          .put(
            Uri.parse(uploadUrl),
            headers: {'Content-Type': contentType},
            body: bytes,
          )
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('No se pudo subir el archivo');
    }
  }

  /// Registers the digital signature of receipt in obra for a remisión,
  /// marking it as firmada. Requires [permisoOperarRemisiones].
  ///
  /// `operadorId` would be the id of whoever receives at the job site (not
  /// the driver), but this app has no lookup against `administracion-service`
  /// to resolve a name to that id, and the schema doesn't mark it required —
  /// so it's optional here, and `comentarios` is where the driver's
  /// hand-typed name of who received goes instead.
  static Future<FirmaResponse> registrarFirma(
    int remisionId, {
    int? operadorId,
    required String firmaDigitalUrl,
    String? evidenciaUrl,
    String? comentarios,
  }) async {
    final data = await _post('/remisiones/$remisionId/firma', {
      if (operadorId != null) 'operadorId': operadorId,
      'firmaDigitalUrl': firmaDigitalUrl,
      if (evidenciaUrl != null) 'evidenciaUrl': evidenciaUrl,
      if (comentarios != null && comentarios.isNotEmpty)
        'comentarios': comentarios,
    });
    return FirmaResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Lists the firmas already registered for a remisión (`GET
  /// /remisiones/{id}/firma`) — a non-empty list is how the app knows the
  /// remisión has been firmada, since [remisionDetalle]'s `RemisionResponse`
  /// has no boolean flag for it.
  static Future<List<FirmaResponse>> firmasPorRemision(int remisionId) async {
    final data = await _get('/remisiones/$remisionId/firma');
    return (data as List<dynamic>)
        .map((e) => FirmaResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Attaches a file/evidencia to a remisión (photo, PDF, etc). `archivoUrl`
  /// is the `publicUrl` from a prior [presignedUploadUrl] +
  /// [subirArchivoPresignado] round trip, same mechanism as
  /// [registrarFirma]. Requires [permisoOperarRemisiones].
  static Future<ArchivoResponse> agregarArchivo(
    int remisionId, {
    required String tipoArchivo,
    required String archivoUrl,
  }) async {
    final data = await _post('/remisiones/$remisionId/archivos', {
      'tipoArchivo': tipoArchivo,
      'archivoUrl': archivoUrl,
    });
    return ArchivoResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Lists the archivos/evidencias already attached to a remisión (`GET
  /// /remisiones/{id}/archivos`).
  static Future<List<ArchivoResponse>> archivosPorRemision(
    int remisionId,
  ) async {
    final data = await _get('/remisiones/$remisionId/archivos');
    return (data as List<dynamic>)
        .map((e) => ArchivoResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fleet-wide — no query param filters by conductor, so callers cross-
  /// reference `conductorAsignadoId` themselves (see
  /// `vehicle/vehiculo_service.dart`'s `miVehiculo`).
  static Future<List<VehiculoResumen>> vehiculos() async {
    final data = await _get('/vehiculos');
    return (data as List<dynamic>)
        .map((e) => VehiculoResumen.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<VehiculoMantenimientoResumen>> mantenimientosVehiculo(
    int vehiculoId,
  ) async {
    final data = await _get('/vehiculos/$vehiculoId/mantenimientos');
    return (data as List<dynamic>)
        .map(
          (e) =>
              VehiculoMantenimientoResumen.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<List<VehiculoPendienteResumen>> pendientesVehiculo(
    int vehiculoId,
  ) async {
    final data = await _get('/pendientes-vehiculos?vehiculoId=$vehiculoId');
    return (data as List<dynamic>)
        .map(
          (e) => VehiculoPendienteResumen.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<List<VehiculoDocumentoResumen>> documentosVehiculo(
    int vehiculoId,
  ) async {
    final data = await _get('/vehiculos/$vehiculoId/documentos');
    return (data as List<dynamic>)
        .map(
          (e) => VehiculoDocumentoResumen.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// `GET /modelos-3d?tipoVehiculoId=` — the catalog entries for a vehicle
  /// type, used as a fallback when a `VehiculoResumen` hasn't been assigned
  /// its own `modelo3dId` yet (see `vehicle/vehiculo_service.dart`).
  static Future<List<Modelo3dResumen>> modelosPorTipoVehiculo(
    int tipoVehiculoId,
  ) async {
    final data = await _get('/modelos-3d?tipoVehiculoId=$tipoVehiculoId');
    return (data as List<dynamic>)
        .map((e) => Modelo3dResumen.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Reports a pendiente (falla mecánica/llanta/mantenimiento/otro) on a
  /// vehicle. `fechaDeteccion` is stamped as today — this is reported at
  /// the moment it's noticed, not scheduled ahead. `evidenciaApertura` is
  /// the `publicUrl` from a prior [presignedUploadUrl] +
  /// [subirArchivoPresignado] round trip — unlike `RemisionFirma`, there's
  /// no separate photo table/endpoint here, it's just another field on the
  /// same `VehiculoPendiente` row. Requires [permisoReportarPendienteVehiculo].
  static Future<void> registrarPendienteVehiculo(
    int vehiculoId, {
    required String tipoPendiente,
    String? descripcion,
    String? evidenciaApertura,
  }) {
    final hoy = DateTime.now();
    final fechaDeteccion =
        '${hoy.year.toString().padLeft(4, '0')}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

    return _post('/vehiculos/$vehiculoId/pendientes', {
      'tipoPendiente': tipoPendiente,
      if (descripcion != null && descripcion.isNotEmpty)
        'descripcion': descripcion,
      if (evidenciaApertura != null) 'evidenciaApertura': evidenciaApertura,
      'fechaDeteccion': fechaDeteccion,
    });
  }

  static Future<dynamic> _get(String path) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http
          .get(Uri.parse('$_baseUrl$path'), headers: headers)
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http
          .patch(
            Uri.parse('$_baseUrl$path'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw AuthException('Respuesta inesperada del servidor');
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map<String, dynamic>
          ? data['message'] as String?
          : null;
      throw AuthException(message ?? 'Ocurrió un error inesperado');
    }
    return data;
  }
}
