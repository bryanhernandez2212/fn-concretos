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

  static Future<void> initialize() => OneSignal.initialize(_appId);

  /// Call once a session is established (login, MFA verify, or a restored
  /// session — see `AuthService._fetchMe`) so backend notifications can
  /// target this device: by `external_id` (`usuarioId`, this account's
  /// auth-service id — the same field `notificacion-controller`'s
  /// `NotificacionCreateRequest.usuarioId` expects, e.g. for "tu remisión ya
  /// puede avanzar" to one specific conductor), or by the `rol`/`permisos`
  /// tags (e.g. for a "todo Dirección" segment built in the OneSignal
  /// dashboard around `pedidos.autorizar_credito`). Deliberately not
  /// `idEmpleado` — that's a different id (the employee record), and
  /// wouldn't match what `usuarioId` refers to.
  static Future<void> syncSession({
    required int? usuarioId,
    required String? rol,
    required List<String> permisos,
  }) async {
    if (usuarioId != null) {
      await OneSignal.login(usuarioId.toString());
    }
    await OneSignal.User.addTags({'rol': rol ?? '', 'permisos': permisos.join(',')});
    await OneSignal.Notifications.requestPermission(true);
  }

  /// Call on logout so a shared/handed-down device stops receiving this
  /// employee's targeted notifications.
  static Future<void> clearSession() => OneSignal.logout();
}
