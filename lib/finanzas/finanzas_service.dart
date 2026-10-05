import 'dart:convert';
import '../config/http_client.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config.dart';
import 'comision.dart';
import 'orden_compra.dart';

/// Talks to the real fnconcretos `finanzas` sandbox (`finanzas-service`,
/// its own `/v3/api-docs`), same `AuthService.authHeaders()` bearer pattern
/// as the other services. Only the read endpoints an Asesor Comercial
/// needs to see their own commissions — not `comision-periodo-controller`'s
/// write side (abrir periodo, agregar detalle, generar corte, autorizar,
/// ajustar, marcar pagada), which are administrative actions gated behind
/// `comisiones.autorizar`/`comisiones.ajustar` and belong to the desktop
/// system.
///
/// Also backs Dirección's "Compras" tab: `orden-compra-controller`'s reads
/// plus autorizar/rechazar only — creating an orden, sending it to
/// authorization and the post-autorización estatus flow stay on desktop.
class FinanzasService {
  static const _baseUrl = ApiConfig.finanzas;

  /// `GET /comisiones-periodo?asesorId=` — `asesorId` is required by the
  /// backend; it's the `Asesor.id` (see `AsesorComercialService.miAsesor`),
  /// not the auth account id.
  static Future<List<ComisionPeriodo>> periodosComision({required int asesorId}) async {
    final data = await _get('/comisiones-periodo?asesorId=$asesorId');
    return (data as List<dynamic>).map((e) => ComisionPeriodo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /comisiones-periodo/proyeccion?asesorId=` — projected (not yet
  /// cut) commissions for the asesor's pedidos. Calculated on the fly
  /// server-side, never persisted; a pedido drops off this list once a real
  /// corte processes it and it shows up under [periodosComision] instead.
  static Future<List<ComisionProyectada>> proyeccionComision({required int asesorId}) async {
    final data = await _get('/comisiones-periodo/proyeccion?asesorId=$asesorId');
    return (data as List<dynamic>).map((e) => ComisionProyectada.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<ComisionPeriodo> periodoComision(int id) async {
    final data = await _get('/comisiones-periodo/$id');
    return ComisionPeriodo.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /ordenes-compra` — no filter: the "por autorizar" estatus value
  /// isn't enumerated in the schema, so narrowing happens client-side via
  /// [OrdenCompra.porAutorizar] rather than guessing `?estatus=`.
  static Future<List<OrdenCompra>> ordenesCompra() async {
    final data = await _get('/ordenes-compra');
    return (data as List<dynamic>).map((e) => OrdenCompra.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /ordenes-compra/{id}` — includes `items`.
  static Future<OrdenCompra> ordenCompra(int id) async {
    final data = await _get('/ordenes-compra/$id');
    return OrdenCompra.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<OrdenCompraBitacora>> bitacoraOrdenCompra(int id) async {
    final data = await _get('/ordenes-compra/$id/bitacora');
    return (data as List<dynamic>).map((e) => OrdenCompraBitacora.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Requires [permisoAutorizarOrdenesCompra].
  static Future<OrdenCompra> autorizarOrdenCompra(int id) async {
    final data = await _patch('/ordenes-compra/$id/autorizar');
    return OrdenCompra.fromJson(data as Map<String, dynamic>);
  }

  /// Requires [permisoAutorizarOrdenesCompra].
  static Future<OrdenCompra> rechazarOrdenCompra(int id, {required String motivo}) async {
    final data = await _patch('/ordenes-compra/$id/rechazar', {'motivoRechazo': motivo});
    return OrdenCompra.fromJson(data as Map<String, dynamic>);
  }

  static Future<dynamic> _patch(String path, [Map<String, dynamic>? body]) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.patch(
        Uri.parse('$_baseUrl$path'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      );
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
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
