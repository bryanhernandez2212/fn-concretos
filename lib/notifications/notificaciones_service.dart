import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config.dart';
import 'notificacion.dart';

/// One page of `GET /notificaciones`, plus whether another page exists —
/// [NotificacionesScreen] uses [hasMore] to decide whether scrolling near
/// the bottom should fetch the next [NotificacionesService.listar] page.
class NotificacionesPage {
  final List<Notificacion> items;
  final bool hasMore;

  const NotificacionesPage({required this.items, required this.hasMore});
}

/// Talks to auth-service's real `notificacion-controller` (same sandbox as
/// [AuthService] — `GET /notificaciones` and friends live there, not under
/// `comercial`/`operaciones`). `POST /notificaciones` isn't called from
/// here: per its own docs it's for other microservices to call when an
/// event happens for a user, not for the UI.
class NotificacionesService {
  static const _baseUrl = ApiConfig.auth;
  static const _timeout = Duration(seconds: 20);

  /// [leida] filters to only read/unread notifications; omit for everything.
  /// Newest first, [size] items per [page] (0-indexed) — [hasMore] backs
  /// the screen's infinite scroll.
  static Future<NotificacionesPage> listar({bool? leida, int page = 0, int size = 20}) async {
    final query = {
      'page': '$page',
      'size': '$size',
      'sort': 'creadoEn,desc',
      if (leida != null) 'leida': '$leida',
    };
    final data = await _get('/notificaciones', query) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? const [];
    final items = content.map((e) => Notificacion.fromJson(e as Map<String, dynamic>)).toList();
    // Spring's Page response carries `last`; fall back to "page came back
    // full" if that field is ever missing, so a short last page still stops.
    final last = data['last'] as bool?;
    final hasMore = last != null ? !last : items.length >= size;
    return NotificacionesPage(items: items, hasMore: hasMore);
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
