import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

/// Thrown by [AuthService.login] when the account has MFA enabled: no
/// tokens were issued yet, and the caller must collect a 6-digit TOTP code
/// and pass [challengeToken] + that code to [AuthService.verifyMfa].
class MfaRequiredException implements Exception {
  final String challengeToken;

  MfaRequiredException(this.challengeToken);
}

/// Secret + QR-less enrollment data returned by [AuthService.enableMfa].
class MfaEnrollment {
  final String secret;
  final String otpAuthUrl;

  const MfaEnrollment({required this.secret, required this.otpAuthUrl});
}

/// Talks to the real fnconcretos auth sandbox (`auth-service`, see its
/// `/v3/api-docs`). Session state is held in static fields — this app has
/// no state-management package and no persistence yet, so this mirrors the
/// existing `themeNotifier` pattern (see main.dart) rather than
/// introducing one.
class AuthService {
  static const _baseUrl = 'https://fnconcretos.app/sandbox/auth';

  static String? accessToken;
  static String? refreshToken;
  static DateTime? _accessTokenExpiresAt;
  static String? username;
  static String? rol;
  static List<String> permisos = const [];

  static bool get isLoggedIn => accessToken != null;

  /// Bearer header for calling other microservices (e.g. `comercial`) that
  /// trust this same auth-service token. Refreshes first if the access
  /// token is stale, so callers never have to think about expiry.
  static Future<Map<String, String>> authHeaders() async {
    await _ensureFreshToken();
    return {'Authorization': 'Bearer $accessToken'};
  }

  /// Logs in and, on success, populates [username]/[rol]/[permisos] from
  /// `/auth/me`. Throws [MfaRequiredException] if the account needs a TOTP
  /// code — call [verifyMfa] with it to finish.
  static Future<void> login(String user, String password) async {
    final data = await _post('/auth/login', {'user': user, 'password': password});

    if (data['mfaRequired'] == true) {
      final challengeToken = data['mfaChallengeToken'] as String?;
      if (challengeToken == null) {
        throw AuthException('El servidor pidió MFA sin enviar el token de reto');
      }
      throw MfaRequiredException(challengeToken);
    }

    _setTokens(data);
    await _fetchMe();
  }

  /// Completes a login that was paused by [MfaRequiredException].
  static Future<void> verifyMfa(String challengeToken, String code) async {
    final data = await _post('/auth/mfa/verify', {
      'challengeToken': challengeToken,
      'code': code,
    });
    _setTokens(data);
    await _fetchMe();
  }

  /// Generates a TOTP secret for the current session; the user scans
  /// [MfaEnrollment.otpAuthUrl] (or enters the secret manually) in an
  /// authenticator app, then confirms with [confirmMfaEnable].
  static Future<MfaEnrollment> enableMfa() async {
    final data = await _post('/auth/mfa/enable', const {}, auth: true);
    return MfaEnrollment(
      secret: data['secret'] as String? ?? '',
      otpAuthUrl: data['otpAuthUrl'] as String? ?? '',
    );
  }

  /// Confirms MFA activation with the code produced from the secret
  /// [enableMfa] just issued. Same endpoint as [verifyMfa], but with no
  /// challenge token — the current session's bearer header identifies the
  /// account instead.
  static Future<void> confirmMfaEnable(String code) async {
    await _post('/auth/mfa/verify', {'challengeToken': '', 'code': code}, auth: true);
  }

  static Future<String> forgotPassword(String correo) async {
    final data = await _post('/auth/forgot-password', {'correo': correo});
    return data['message'] as String? ?? 'Si el correo existe, se envió un enlace de recuperación';
  }

  static Future<String> resetPassword(String token, String newPassword) async {
    final data = await _post('/auth/reset-password', {'token': token, 'newPassword': newPassword});
    return data['message'] as String? ?? 'Contraseña restablecida';
  }

  static Future<String> changePassword(String currentPassword, String newPassword) async {
    final data = await _post('/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }, auth: true);
    return data['message'] as String? ?? 'Contraseña actualizada';
  }

  static Future<void> logout() async {
    final token = accessToken;
    final refresh = refreshToken;
    _clearSession();

    if (token == null || refresh == null) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'refreshToken': refresh}),
      );
    } catch (_) {
      // Best-effort: the local session is already cleared above.
    }
  }

  static void _clearSession() {
    accessToken = null;
    refreshToken = null;
    _accessTokenExpiresAt = null;
    username = null;
    rol = null;
    permisos = const [];
  }

  static void _setTokens(Map<String, dynamic> data) {
    accessToken = data['accessToken'] as String?;
    refreshToken = data['refreshToken'] as String?;
    if (accessToken == null) {
      throw AuthException('Respuesta de login sin token de acceso');
    }
    final expiresIn = data['expiresIn'] as int?;
    _accessTokenExpiresAt = expiresIn == null ? null : DateTime.now().add(Duration(seconds: expiresIn));
  }

  /// Renews the access token (rotating the refresh token) if it's expired
  /// or about to expire, so a long-lived session doesn't just die mid-use —
  /// called before every authenticated request instead of forcing a
  /// re-login as soon as the access token goes stale.
  static Future<void> _ensureFreshToken() async {
    if (accessToken == null || refreshToken == null) return;
    final expiresAt = _accessTokenExpiresAt;
    if (expiresAt != null && DateTime.now().isBefore(expiresAt.subtract(const Duration(seconds: 30)))) {
      return;
    }
    final data = await _post('/auth/refresh', {'refreshToken': refreshToken});
    _setTokens(data);
  }

  /// `/auth/me` is the documented source of truth for who's logged in —
  /// more reliable than guessing at undocumented JWT claim names.
  static Future<void> _fetchMe() async {
    final data = await _get('/auth/me', auth: true);
    username = data['user'] as String?;
    rol = data['rolNombre'] as String?;
    permisos = (data['permisos'] as List<dynamic>?)?.cast<String>() ?? const [];
  }

  static Future<Map<String, dynamic>> _get(String path, {bool auth = false}) async {
    if (auth) await _ensureFreshToken();
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$_baseUrl$path'),
        headers: auth ? {'Authorization': 'Bearer $accessToken'} : const {},
      );
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {bool auth = false}) async {
    if (auth) await _ensureFreshToken();
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          if (auth && accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      throw AuthException('No se pudo conectar con el servidor');
    }
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final data = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(data['message'] as String? ?? 'Ocurrió un error inesperado');
    }
    return data;
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AuthException('Respuesta inesperada del servidor');
    }
  }
}
