import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Wraps the OneSignal Flutter SDK — the one place in the app that talks to
/// `OneSignal.*` directly, mirroring how `AuthService` wraps auth-service.
/// Takes plain values from [AuthService] rather than importing it, so there's
/// no circular import between `auth/` and this folder.
///
/// This only covers *registering* the device: identifying who's holding it
/// (`external_id`) and tagging it (`rol`/`permisos`) so backend can target
/// it. Actually sending a notification — "pedido nuevo pendiente de
/// autorización", "remisión salió de planta", "hito listo para avanzar" —
/// is a backend concern: `comercial-service`/`operaciones-service` have to
/// call OneSignal's REST API (Create Notification) when those events
/// happen, targeting by the external_id or tags this class sets. Nothing
/// in this Flutter app can trigger those sends itself.
class OneSignalService {
  OneSignalService._();

  static const _appId = '076ef77e-2eff-46d3-8197-43802e38af11';

  /// The external_id of the current session, kept so [_reLogin] can
  /// re-assert it once push is actually usable (see [initialize]).
  static String? _externalId;

  static Future<void> initialize() async {
    if (kDebugMode) OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    await OneSignal.initialize(_appId);
    // `login` can run before the SDK has a push subscription/permission —
    // on a fresh install `syncSession` fires right after `/auth/me`, before
    // the permission prompt is even shown — so re-assert the external_id
    // the moment permission is granted or the subscription changes, rather
    // than trusting that first call alone.
    OneSignal.Notifications.addPermissionObserver((granted) {
      if (granted) _reLogin('permission');
    });
    OneSignal.User.pushSubscription.addObserver((state) {
      if (state.current.id != null) _reLogin('subscription');
    });
  }

  static Future<void> _reLogin(String reason) async {
    final id = _externalId;
    if (id == null) return;
    try {
      await OneSignal.login(id);
      debugPrint('OneSignal: login($id) re-asserted ($reason)');
    } catch (e) {
      debugPrint('OneSignal: login($id) failed ($reason): $e');
    }
  }

  /// Call once a session is established (login, MFA verify, or a restored
  /// session — see `AuthService._fetchMe`) so backend notifications can
  /// target this device: by `external_id` (`usuarioId`, this account's
  /// auth-service id, prefixed with `fn` — backend rejects/never persists a
  /// bare numeric external_id equal to a restricted value like `1`, so every
  /// external_id is now sent as `fn$usuarioId` on both sides; the same field
  /// `notificacion-controller`'s `NotificacionCreateRequest.usuarioId`
  /// expects, e.g. for "tu remisión ya puede avanzar" to one specific
  /// conductor), or by the `rol`/`permisos` tags (e.g. for a "todo
  /// Dirección" segment built in the OneSignal dashboard around
  /// `pedidos.autorizar_credito`). Deliberately not `idEmpleado` — that's a
  /// different id (the employee record), and wouldn't match what
  /// `usuarioId` refers to.
  static Future<void> syncSession({
    required int? usuarioId,
    required String? rol,
    required List<String> permisos,
  }) async {
    if (usuarioId != null) {
      _externalId = 'fn$usuarioId';
      await OneSignal.login(_externalId!);
      debugPrint('OneSignal: login($_externalId)');
    }
    await OneSignal.User.addTags({'rol': rol ?? '', 'permisos': permisos.join(',')});
  }

  /// Prompts the OS push-permission dialog (a one-time system dialog on
  /// iOS; the Android 13+ runtime permission on Android). Deliberately
  /// **not** called from [syncSession] — `syncSession` also runs off
  /// `AuthService.restoreSession()`, i.e. every app launch that silently
  /// resumes a saved session from the splash screen, which is exactly the
  /// "ask before showing anything of value" pattern to avoid. Only
  /// `AuthService.login`/`verifyMfa` request it, since those already follow
  /// an explicit user action (typing credentials / a TOTP code).
  static Future<void> requestPushPermission() async {
    final granted = await OneSignal.Notifications.requestPermission(true);
    debugPrint('OneSignal: push permission granted=$granted');
    if (granted) await _reLogin('permission prompt');
  }

  /// Call on logout so a shared/handed-down device stops receiving this
  /// employee's targeted notifications.
  static Future<void> clearSession() {
    _externalId = null;
    return OneSignal.logout();
  }

  /// Registers the handler for tapping a push notification — app closed,
  /// backgrounded, or foregrounded. The backend doesn't send
  /// `referenciaTipo`/`referenciaId` as OneSignal `data` yet (title/mensaje
  /// only), so [onClick] will usually see both as null; [onClick] should
  /// treat that as "nothing to deep-link to" the same way
  /// `NotificacionesScreen` already does for the in-app list, rather than
  /// guessing. Call once from `main()`, right after [initialize] and before
  /// `runApp`, so a cold start via notification tap isn't missed.
  static void registerClickListener(void Function(String? referenciaTipo, String? referenciaId) onClick) {
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      onClick(data?['referenciaTipo'] as String?, data?['referenciaId']?.toString());
    });
  }
}
