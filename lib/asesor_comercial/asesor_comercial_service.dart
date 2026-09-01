import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../direccion/pedido.dart';
import 'agenda_actividad.dart';
import 'asesor.dart';
import 'cotizacion.dart';
import 'solicitud_diseno.dart';
import 'visita.dart';

/// Granular permission names (as returned in `/auth/me`'s `permisos`) that
/// gate the Asesor Comercial screens — same reasoning as
/// `comercial_service.dart`'s `permisoAutorizarCredito`: checked instead of
/// `AuthService.rol` so access follows the backend's permission catalog
/// rather than a hardcoded role name.
const permisoAdministrarAgenda = 'agenda.administrar';
const permisoAplicarDescuentoEspecial = 'cotizaciones.aplicar_descuento_especial';
const permisoAdministrarPreciosCatalogo = 'catalogo.precios.administrar';

/// Talks to the real fnconcretos `comercial` sandbox (same base URL as
/// `direccion/comercial_service.dart`) for the Asesor Comercial role's own
/// entities: asesores, visitas, agenda, cotizaciones, solicitudes de diseño.
/// Reuses [AuthService.authHeaders] for the bearer token; this app has no
/// state-management package, so results are returned directly rather than
/// cached anywhere.
class AsesorComercialService {
  static const _baseUrl = 'https://fnconcretos.app/sandbox/comercial';

  /// Resolves the logged-in advisor's own `Asesor` row. There's no backend
  /// concept of "mi asesor" as a single call — `GET /asesores` is
  /// unfiltered, so this fetches everything and keeps the one whose
  /// `usuarioId` matches `AuthService.usuarioId` — the *account* id, not
  /// `idEmpleado` (same distinction `OneSignalService.syncSession` relies
  /// on), since `AsesorResponse.usuarioId` links to the account record, not
  /// the employee one.
  static Future<Asesor?> miAsesor() async {
    final data = await _get('/asesores');
    final usuarioId = AuthService.usuarioId;
    for (final entry in data as List<dynamic>) {
      final asesor = Asesor.fromJson(entry as Map<String, dynamic>);
      if (asesor.usuarioId == usuarioId) return asesor;
    }
    return null;
  }

  static Future<RutaDiaria> rutaDiaria({required int asesorId, required DateTime fecha}) async {
    final data = await _get('/agenda/ruta-diaria?asesorId=$asesorId&fecha=${_fechaSolo(fecha)}');
    return RutaDiaria.fromJson(data as Map<String, dynamic>);
  }

  /// Overdue pending activities, plant/advisor-wide — surfaced as a warning
  /// banner on the Agenda tab.
  static Future<List<AgendaActividad>> actividadesVencidas() async {
    final data = await _get('/agenda/pendientes-vencidas');
    return (data as List<dynamic>).map((e) => AgendaActividad.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Requires [permisoAdministrarAgenda].
  static Future<AgendaActividad> crearActividad({
    required int asesorId,
    required DateTime fechaHora,
    required TipoActividad tipoActividad,
    int? clienteId,
    int? obraId,
    int? cotizacionId,
    int? pedidoId,
    int? minutosRecordatorio,
    String? observaciones,
  }) async {
    final data = await _post('/agenda', {
      'asesorId': asesorId,
      'fechaHora': _fechaHoraIso(fechaHora),
      'tipoActividad': tipoActividad.backendValue,
      if (clienteId != null) 'clienteId': clienteId,
      if (obraId != null) 'obraId': obraId,
      if (cotizacionId != null) 'cotizacionId': cotizacionId,
      if (pedidoId != null) 'pedidoId': pedidoId,
      if (minutosRecordatorio != null) 'minutosRecordatorio': minutosRecordatorio,
      if (observaciones != null && observaciones.isNotEmpty) 'observaciones': observaciones,
    });
    return AgendaActividad.fromJson(data as Map<String, dynamic>);
  }

  /// `estatus` is `'completada'` or `'cancelada'`. Requires
  /// [permisoAdministrarAgenda].
  static Future<void> actualizarEstatusActividad(int actividadId, {required String estatus}) {
    return _patch('/agenda/$actividadId/estatus', {'estatus': estatus});
  }

  static Future<List<Visita>> visitasDelDia({required int asesorId, required DateTime fecha}) async {
    final data = await _get('/visitas?asesorId=$asesorId&fecha=${_fechaSolo(fecha)}');
    return (data as List<dynamic>).map((e) => Visita.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<ResumenVisitas> resumenVisitasDelDia({required int asesorId, required DateTime fecha}) async {
    final data = await _get('/visitas/resumen-dia?asesorId=$asesorId&fecha=${_fechaSolo(fecha)}');
    return ResumenVisitas.fromJson(data as Map<String, dynamic>);
  }

  /// Registers a geolocated check-in for a visita. No permission requirement
  /// is documented for this beyond being logged in as the assigned asesor —
  /// unlike `OperacionesService`'s `remisiones.operar` gate, there's no
  /// analogous permission for visitas in the Asesor Comercial permission set.
  static Future<Visita> checkin(
    int visitaId, {
    required double latitud,
    required double longitud,
    String? fotoEvidenciaUrl,
    String? contactoNombre,
    String? contactoTelefono,
    String? metodoCheckin,
  }) async {
    final data = await _post('/visitas/$visitaId/checkin', {
      'latitud': latitud,
      'longitud': longitud,
      if (fotoEvidenciaUrl != null) 'fotoEvidenciaUrl': fotoEvidenciaUrl,
      if (contactoNombre != null && contactoNombre.isNotEmpty) 'contactoNombre': contactoNombre,
      if (contactoTelefono != null && contactoTelefono.isNotEmpty) 'contactoTelefono': contactoTelefono,
      if (metodoCheckin != null) 'metodoCheckin': metodoCheckin,
    });
    return Visita.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /cotizaciones` has no `asesorId` filter, so this fetches by
  /// `estatus` (optional) and narrows client-side to [asesorId] — same
  /// "fetch broad, filter client-side" idiom as
  /// `OperacionesService.remisionesEnRuta`.
  static Future<List<Cotizacion>> misCotizaciones({required int asesorId, String? estatus}) async {
    final query = estatus == null ? '' : '?estatus=$estatus';
    final data = await _get('/cotizaciones$query');
    return (data as List<dynamic>)
        .map((e) => Cotizacion.fromJson(e as Map<String, dynamic>))
        .where((c) => c.asesorId == asesorId)
        .toList();
  }

  static Future<Cotizacion> obtenerCotizacion(int id) async {
    final data = await _get('/cotizaciones/$id');
    return Cotizacion.fromJson(data as Map<String, dynamic>);
  }

  /// `porcentajeDescuento` should only be passed when the caller holds
  /// [permisoAplicarDescuentoEspecial] — enforced by the caller (UI hides
  /// the field otherwise), not by this method.
  static Future<Cotizacion> crearCotizacion({
    required int clienteId,
    required double volumenM3,
    required double precioUnitario,
    int? obraId,
    int? contactoId,
    int? plantaId,
    int? asesorId,
    int? productoId,
    String? tipoServicio,
    DateTime? fechaSuministroEstimada,
    String? formaPago,
    bool? requiereFactura,
    double? porcentajeDescuento,
  }) async {
    final data = await _post('/cotizaciones', {
      'clienteId': clienteId,
      'volumenM3': volumenM3,
      'precioUnitario': precioUnitario,
      if (obraId != null) 'obraId': obraId,
      if (contactoId != null) 'contactoId': contactoId,
      if (plantaId != null) 'plantaId': plantaId,
      if (asesorId != null) 'asesorId': asesorId,
      if (productoId != null) 'productoId': productoId,
      if (tipoServicio != null) 'tipoServicio': tipoServicio,
      if (fechaSuministroEstimada != null) 'fechaSuministroEstimada': _fechaSolo(fechaSuministroEstimada),
      if (formaPago != null) 'formaPago': formaPago,
      if (requiereFactura != null) 'requiereFactura': requiereFactura,
      if (porcentajeDescuento != null) 'porcentajeDescuento': porcentajeDescuento,
    });
    return Cotizacion.fromJson(data as Map<String, dynamic>);
  }

  /// `estatus` is `'negociacion'`, `'listo'`, or `'cancelada'` — `'convertida'`
  /// is set server-side by [convertirAPedido], not settable directly.
  static Future<void> actualizarEstatusCotizacion(int id, {required String estatus}) {
    return _patch('/cotizaciones/$id/estatus', {'estatus': estatus});
  }

  static Future<Cotizacion> duplicarCotizacion(int id) async {
    final data = await _post('/cotizaciones/$id/duplicar', const {});
    return Cotizacion.fromJson(data as Map<String, dynamic>);
  }

  /// Converts a `listo` cotización into a real Pedido — the response shares
  /// `Pedido`'s field names (`volumenSolicitadoM3`, `estatusGeneral`, etc.),
  /// so it's parsed with the same DTO Dirección's screens use rather than a
  /// new one.
  static Future<Pedido> convertirAPedido(
    int cotizacionId, {
    required DateTime fechaProgramada,
    required String condicionPago,
    int? diasCredito,
  }) async {
    final data = await _post('/cotizaciones/$cotizacionId/convertir-pedido', {
      'fechaProgramada': _fechaSolo(fechaProgramada),
      'condicionPago': condicionPago,
      if (diasCredito != null) 'diasCredito': diasCredito,
    });
    return Pedido.fromJson(data as Map<String, dynamic>);
  }

  /// Creates a special mix-design request ahead of quoting. Resolving
  /// viabilidad is a laboratorio-side action (`PATCH .../viabilidad`), out
  /// of scope for this role.
  static Future<SolicitudDiseno> crearSolicitudDiseno({
    required int clienteId,
    int? obraId,
    String? productoSolicitado,
    String? revenimiento,
    String? tamanoAgregado,
    String? caracteristicaEspecial,
    String? aditivosRequeridos,
    DateTime? fechaDeseada,
    DateTime? fechaLimiteRespuesta,
    String? insumosRequeridos,
    String? evidenciaUrl,
  }) async {
    final data = await _post('/solicitudes-diseno', {
      'clienteId': clienteId,
      if (obraId != null) 'obraId': obraId,
      if (productoSolicitado != null) 'productoSolicitado': productoSolicitado,
      if (revenimiento != null) 'revenimiento': revenimiento,
      if (tamanoAgregado != null) 'tamanoAgregado': tamanoAgregado,
      if (caracteristicaEspecial != null) 'caracteristicaEspecial': caracteristicaEspecial,
      if (aditivosRequeridos != null) 'aditivosRequeridos': aditivosRequeridos,
      if (fechaDeseada != null) 'fechaDeseada': _fechaSolo(fechaDeseada),
      if (fechaLimiteRespuesta != null) 'fechaLimiteRespuesta': _fechaSolo(fechaLimiteRespuesta),
      if (insumosRequeridos != null) 'insumosRequeridos': insumosRequeridos,
      if (evidenciaUrl != null) 'evidenciaUrl': evidenciaUrl,
    });
    return SolicitudDiseno.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<SolicitudDiseno>> solicitudesDiseno({String? estatus}) async {
    final query = estatus == null ? '' : '?estatus=$estatus';
    final data = await _get('/solicitudes-diseno$query');
    return (data as List<dynamic>).map((e) => SolicitudDiseno.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String _fechaSolo(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }

  static String _fechaHoraIso(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${_fechaSolo(d)}T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  static Future<dynamic> _get(String path) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.get(Uri.parse('$_baseUrl$path'), headers: headers);
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.patch(
        Uri.parse('$_baseUrl$path'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
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
      final message = data is Map<String, dynamic> ? data['message'] as String? : null;
      throw AuthException(message ?? 'Ocurrió un error inesperado');
    }
    return data;
  }
}
