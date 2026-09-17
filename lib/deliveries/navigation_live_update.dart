import 'dart:io';
import 'package:flutter/services.dart';

/// Thin wrapper around `MainActivity.kt`'s `MethodChannel`, which forwards
/// to `NavigationLiveUpdateManager.kt` — the Android 16 "Live Update"
/// promoted notification (lock-screen/status-bar card) `RouteNavigationScreen`
/// shows while navigating. There's no pub.dev package for this native-only
/// notification API, unlike the rest of this app's Android integrations.
///
/// No-op on iOS/other platforms (the channel only exists on Android) and
/// best-effort everywhere else: a failed platform call here is never worth
/// interrupting navigation over, same convention as this screen's own
/// GPS-ping/hito calls.
class NavigationLiveUpdate {
  static const _channel = MethodChannel('fn_concretos/navigation_live_update');

  /// Posts the initial notification, indeterminate until the first
  /// [update] call has real route progress to show. [remisionId] is
  /// embedded in the notification's tap intent (see [MainActivity]) purely
  /// so tapping it can deep-link back into that delivery — the notification
  /// itself doesn't need it to render.
  static Future<void> start({
    required String folio,
    required String destino,
    int? remisionId,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('start', {
        'folio': folio,
        'destino': destino,
        'remisionId': remisionId,
      });
    } catch (_) {}
  }

  /// Moves the progress bar and refreshes the ETA — call repeatedly as the
  /// drive progresses.
  static Future<void> update({
    required String folio,
    required String destino,
    required double remainingDistanceMetros,
    required double remainingTimeSeconds,
    int? remisionId,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('update', {
        'folio': folio,
        'destino': destino,
        'remainingDistanceMetros': remainingDistanceMetros,
        'remainingTimeSeconds': remainingTimeSeconds,
        'remisionId': remisionId,
      });
    } catch (_) {}
  }

  /// Call on arrival, or if the driver exits navigation early — nothing
  /// left to show progress for either way.
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  /// Cold-start case: call once at app startup to ask whether *this*
  /// launch was caused by tapping the Live Update notification — the
  /// Android Activity that was already running (if any) got a fresh
  /// `Intent`, but a brand-new process/Activity only has that `Intent` to
  /// go on. Consumes it natively (returns it once, then clears it) so a
  /// later hot-restart/rebuild doesn't re-trigger the same navigation.
  /// Always null on iOS/other platforms.
  static Future<int?> consumeLaunchRemisionId() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('consumeLaunchRemisionId');
    } catch (_) {
      return null;
    }
  }

  /// Warm-resume case: the app was already running (singleTop) when the
  /// notification was tapped, so Android delivers the new `Intent` via
  /// `onNewIntent` instead of a fresh launch — `MainActivity` pushes it
  /// straight to Dart through this handler rather than Dart having to poll
  /// for it. No-op on iOS/other platforms (nothing ever calls it there).
  static void registerNotificationTapListener(void Function(int remisionId) onTap) {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap') {
        final remisionId = call.arguments['remisionId'] as int?;
        if (remisionId != null) onTap(remisionId);
      }
    });
  }
}
