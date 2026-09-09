import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../config/api_config.dart';
import '../operaciones/evidencia.dart' show PresignedUploadResponse;
import 'empleado.dart';

/// Talks to the real fnconcretos `administracion` sandbox (see its
/// `/v3/api-docs`) — HR employee records. Backs `ProfileScreen`'s fuller
/// profile data (nombreCompleto/puesto/área/teléfono) and the real,
/// backend-synced `fotoPerfilUrl`, since `auth-service`'s `/auth/me` only
/// has username/rol/correo/permisos. Reuses [AuthService.authHeaders] for
/// the bearer token, same pattern as `ComercialService`/`OperacionesService`.
class AdministracionService {
  static const _baseUrl = ApiConfig.administracion;
  static const _timeout = Duration(seconds: 20);

  static Future<EmpleadoResponse> obtenerEmpleado(int id) async {
    final data = await _get('/empleados/$id');
    return EmpleadoResponse.fromJson(data as Map<String, dynamic>);
  }

  /// `PUT /empleados/{id}` replaces the whole record — pass the [actual]
  /// record just fetched so its other fields round-trip unchanged, only
  /// [fotoPerfilUrl] differs.
  static Future<EmpleadoResponse> actualizarFotoPerfil(
    int id,
    EmpleadoResponse actual,
    String fotoPerfilUrl,
  ) async {
    final data = await _put(
      '/empleados/$id',
      actual.toRequestJson(fotoPerfilUrl: fotoPerfilUrl),
    );
    return EmpleadoResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Requests a presigned upload URL for `carpeta`/`nombreArchivo` — same
  /// mechanism as `OperacionesService.presignedUploadUrl`, just issued by
  /// this service instead. Use `OperacionesService.subirArchivoPresignado`
  /// for the actual `PUT` to storage; that helper is base-URL-agnostic.
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

  static Future<dynamic> _get(String path) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http.get(Uri.parse('$_baseUrl$path'), headers: headers).timeout(_timeout);
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

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final headers = await AuthService.authHeaders();
    final http.Response response;
    try {
      response = await http
          .put(
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
      final message = data is Map<String, dynamic> ? data['message'] as String? : null;
      throw AuthException(message ?? 'Ocurrió un error inesperado');
    }
    return data;
  }
}
