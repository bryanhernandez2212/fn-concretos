import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config.dart';
import 'comision.dart';

/// Talks to the real fnconcretos `finanzas` sandbox (`finanzas-service`,
/// its own `/v3/api-docs`), same `AuthService.authHeaders()` bearer pattern
/// as the other services. Only the read endpoints an Asesor Comercial
/// needs to see their own commissions — not `comision-periodo-controller`'s
/// write side (abrir periodo, agregar detalle, generar corte, autorizar,
/// ajustar, marcar pagada), which are administrative actions gated behind
/// `comisiones.autorizar`/`comisiones.ajustar` and belong to the desktop
/// system.
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
