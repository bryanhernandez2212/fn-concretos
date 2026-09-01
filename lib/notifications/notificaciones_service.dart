import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import 'notificacion.dart';

/// Talks to auth-service's real `notificacion-controller` (same sandbox as
/// [AuthService] — `GET /notificaciones` and friends live there, not under
/// `comercial`/`operaciones`). `POST /notificaciones` isn't called from
/// here: per its own docs it's for other microservices to call when an
/// event happens for a user, not for the UI.
class NotificacionesService {
  static const _baseUrl = 'https://fnconcretos.app/sandbox/auth';
  static const _timeout = Duration(seconds: 20);

  /// [leida] filters to only read/unread notifications; omit for everything.
  /// [size] is a flat page (no infinite-scroll UI yet), newest first.
  static Future<List<Notificacion>> listar({bool? leida, int size = 50}) async {
    final query = {
      'page': '0',
      'size': '$size',
      'sort': 'creadoEn,desc',
      if (leida != null) 'leida': '$leida',
    };
    final data = await _get('/notificaciones', query);
    final content = (data as Map<String, dynamic>)['content'] as List<dynamic>? ?? const [];
    return content.map((e) => Notificacion.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The response shape is a generic `{key: count}` map (backend hasn't
  /// fixed a property name for it) — take whatever single value comes back
  /// rather than assuming a specific key.
  static Future<int> contarNoLeidas() async {
    final data = await _get('/notificaciones/no-leidas/conteo', const {});
    final map = data as Map<String, dynamic>;
    if (map.isEmpty) return 0;
    return (map.values.first as num).toInt();
  }

  static Future<void> marcarLeida(int id) => _patch('/notificaciones/$id/leida');

  static Future<void> marcarTodasLeidas() => _patch('/notificaciones/leidas');

  static Future<dynamic> _get(String path, Map<String, String> query) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http
          .get(Uri.parse('$_baseUrl$path').replace(queryParameters: query.isEmpty ? null : query), headers: headers)
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Future<dynamic> _patch(String path) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.patch(Uri.parse('$_baseUrl$path'), headers: headers).timeout(_timeout);
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
