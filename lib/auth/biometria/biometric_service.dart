import 'package:local_auth/local_auth.dart';

/// Thin wrapper around `local_auth`'s Face ID/Touch ID (iOS) and
/// biometric/device-credential (Android) prompts — kept separate from
/// [AuthService] since it talks to the OS, not the backend: it decides
/// whether *this device* recognizes the person holding it, nothing about
/// the account itself.
class BiometricService {
  static final _auth = LocalAuthentication();

  /// Whether this device can prompt for Face ID/Touch ID/fingerprint at
  /// all — false on simulators or devices with no biometrics enrolled, so
  /// `ProfileScreen` can hide the toggle entirely rather than offering a
  /// setting that would always fail.
  static Future<bool> disponible() async {
    try {
      final soportado = await _auth.isDeviceSupported();
      final puedeChecar = await _auth.canCheckBiometrics;
      return soportado && puedeChecar;
    } catch (_) {
      return false;
    }
  }

  /// Prompts Face ID/Touch ID/fingerprint (falling back to the device's own
  /// passcode/PIN/pattern UI, same as the OS does everywhere else — this
  /// isn't a stricter security boundary than unlocking the phone itself).
  /// Never throws: any `PlatformException` (cancelled, locked out, no
  /// biometrics enrolled, etc.) is treated the same as "not authenticated".
  static Future<bool> autenticar(String razon) async {
    try {
      return await _auth.authenticate(
        localizedReason: razon,
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (_) {
      return false;
    }
  }
}
