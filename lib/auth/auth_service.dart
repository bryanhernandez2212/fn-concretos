import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _storage = FlutterSecureStorage();
  static const _refreshTokenKey = 'fn_concretos_refresh_token';

  static String? accessToken;
  static String? refreshToken;
  static DateTime? _accessTokenExpiresAt;
  static String? username;
  static String? rol;
  static String? correo;
  static List<String> permisos = const [];

  /// Whether the account has TOTP MFA enabled, per `/auth/me`'s
  /// `mfaHabilitado`. The API docs mark MFA enrollment as mandatory for
  /// Dirección/Pagos, but the backend doesn't block login over it, so the
  /// app surfaces this instead (see `ProfileScreen`'s MFA tile and
  /// `DireccionHomeScreen`'s enrollment nudge) rather than assuming an
  /// unenrolled account can't happen.
  static bool mfaHabilitado = false;

  /// The employee id backing this session. Used to cross-reference records
  /// in other microservices that identify a person by employee id rather
  /// than username — e.g. `operaciones`'s `AsignacionResponse.conductorId`
  /// (see `deliveries/entregas_service.dart`), on the assumption that both
  /// services share the same employee id space.
  static int? idEmpleado;

  /// Whether the current session's refresh token should be persisted to
  /// secure storage (i.e. whether the "Recordar sesión" checkbox was on at
  /// login) — set on [login]/[verifyMfa]/[restoreSession] and consulted by
  /// every subsequent [_setTokens] call, including background renewals from
  /// [_ensureFreshToken], so the choice sticks for the whole session.
  static bool _rememberSession = false;

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
  /// code — call [verifyMfa] with it to finish. [rememberSession] controls
  /// whether the refresh token gets persisted so [restoreSession] can pick
  /// it up on a future launch.
  static Future<void> login(String user, String password, {bool rememberSession = false}) async {
    _rememberSession = rememberSession;
    final data = await _post('/auth/login', {'user': user, 'password': password});

    if (data['mfaRequired'] == true) {
      final challengeToken = data['mfaChallengeToken'] as String?;
      if (challengeToken == null) {
        throw AuthException('El servidor pidió MFA sin enviar el token de reto');
      }
      throw MfaRequiredException(challengeToken);
    }

    await _setTokens(data);
    await _fetchMe();
  }

  /// Completes a login that was paused by [MfaRequiredException].
  static Future<void> verifyMfa(String challengeToken, String code, {bool rememberSession = false}) async {
    _rememberSession = rememberSession;
    final data = await _post('/auth/mfa/verify', {
      'challengeToken': challengeToken,
      'code': code,
    });
    await _setTokens(data);
    await _fetchMe();
  }

  /// Tries to resume a previous session from the refresh token persisted in
  /// secure storage (Keychain/Keystore), so the app doesn't force a
  /// re-login every time it's reopened. Returns false — leaving the session
  /// clean — if there's no stored token or the backend no longer accepts it
  /// (expired/revoked).
  static Future<bool> restoreSession() async {
    final storedRefreshToken = await _storage.read(key: _refreshTokenKey);
    if (storedRefreshToken == null) return false;

    try {
      _rememberSession = true;
      final data = await _post('/auth/refresh', {'refreshToken': storedRefreshToken});
      await _setTokens(data);
      await _fetchMe();
      return true;
    } catch (_) {
      _clearSession();
      await _storage.delete(key: _refreshTokenKey);
      return false;
    }
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
    mfaHabilitado = true;
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
    try {
      await _storage.delete(key: _refreshTokenKey);
    } catch (_) {
      // Best-effort: the in-memory session is already cleared above.
    }

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
    correo = null;
    permisos = const [];
    idEmpleado = null;
    mfaHabilitado = false;
    _rememberSession = false;
  }

  static Future<void> _setTokens(Map<String, dynamic> data) async {
    accessToken = data['accessToken'] as String?;
    refreshToken = data['refreshToken'] as String?;
    if (accessToken == null) {
      throw AuthException('Respuesta de login sin token de acceso');
    }
    final expiresIn = data['expiresIn'] as int?;
    _accessTokenExpiresAt = expiresIn == null ? null : DateTime.now().add(Duration(seconds: expiresIn));

    // The refresh token rotates on every use (including background renewals
    // from _ensureFreshToken), so re-persist it here rather than only at
    // login — but only if the user opted into "Recordar sesión"; otherwise
    // make sure nothing lingers from a previous remembered session.
    // Best-effort: a secure-storage hiccup shouldn't break the actual auth
    // flow, just mean the session isn't remembered next launch.
    try {
      if (refreshToken == null || !_rememberSession) {
        await _storage.delete(key: _refreshTokenKey);
      } else {
        await _storage.write(key: _refreshTokenKey, value: refreshToken!);
      }
    } catch (_) {}
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
    await _setTokens(data);
  }

  /// `/auth/me` is the documented source of truth for who's logged in —
  /// more reliable than guessing at undocumented JWT claim names.
  static Future<void> _fetchMe() async {
    final data = await _get('/auth/me', auth: true);
    username = data['user'] as String?;
    rol = data['rolNombre'] as String?;
    correo = data['correo'] as String?;
    permisos = (data['permisos'] as List<dynamic>?)?.cast<String>() ?? const [];
    idEmpleado = data['idEmpleado'] as int?;
    mfaHabilitado = data['mfaHabilitado'] as bool? ?? false;
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
