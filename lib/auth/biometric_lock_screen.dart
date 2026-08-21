import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'login_screen.dart';

/// Shown right after `SplashScreen` restores a session, when the user has
/// opted into Face ID/Touch ID quick login (`AuthService.biometricHabilitado`).
/// The restored session already lives in `AuthService`'s static fields —
/// this screen is purely a local gate in front of it, not a second factor
/// the backend knows about.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _autenticando = false;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _autenticar();
  }

  Future<void> _autenticar() async {
    setState(() {
      _autenticando = true;
      _fallo = false;
    });
    final ok = await BiometricService.autenticar('Confirma tu identidad para entrar a FN Concretos');
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => destinationForSession()),
      );
      return;
    }
    setState(() {
      _autenticando = false;
      _fallo = true;
    });
  }

  void _usarContrasena() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Same color as the native launch screen/SplashScreen, so leaving the
      // video and landing here reads as one continuous flow.
      backgroundColor: const Color(0xFF15181B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.face_retouching_natural, size: 64, color: AppColors.accent),
                const SizedBox(height: 20),
                Text(
                  AuthService.username != null ? 'Hola, ${AuthService.username}' : 'Bienvenido de nuevo',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _autenticando
                      ? 'Verificando...'
                      : (_fallo ? 'No se pudo verificar tu identidad.' : 'Confirma tu identidad para continuar.'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (_autenticando)
                  const CircularProgressIndicator(color: AppColors.accent)
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _autenticar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _usarContrasena,
                    child: const Text('Usar contraseña', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
