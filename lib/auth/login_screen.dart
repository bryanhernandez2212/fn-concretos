import 'dart:ui';
import 'package:flutter/material.dart';
import '../direccion/comercial_service.dart';
import '../direccion/direccion_home_screen.dart';
import '../home/home_screen.dart';
import '../models/login_background.dart';
import 'auth_service.dart';
import 'forgot_password_screen.dart';
import 'mfa_verification_dialog.dart';
import 'role_unavailable_screen.dart';
import 'roles.dart';

/// Field operators (see [rolesConAppMovil]) go to [HomeScreen] by role
/// name — that pair of roles is hardcoded in this build regardless of
/// permissions. Everyone else is routed by *permission*, not role name:
/// whoever holds `pedidos.autorizar_credito` gets [DireccionHomeScreen],
/// since the backend's roles-controller lets that permission move to a
/// different or renamed role independently of this app. No mobile
/// screens exist for anyone else yet, so they see [RoleUnavailableScreen].
/// Shared by [LoginScreen] (after a fresh login) and [SplashScreen] (after
/// silently restoring a persisted session).
Widget destinationForSession() {
  if (rolesConAppMovil.contains(AuthService.rol)) {
    return const HomeScreen();
  } else if (AuthService.permisos.contains(permisoAutorizarCredito)) {
    return const DireccionHomeScreen();
  } else {
    return const RoleUnavailableScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
  bool _submitting = false;
  bool _rememberSession = false;
  String? _errorText;
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await AuthService.login(
        _userController.text.trim(),
        _passwordController.text,
        rememberSession: _rememberSession,
      );
      if (!mounted) return;
      _navigateAfterLogin();
      return;
    } on MfaRequiredException catch (e) {
      final verified = await showMfaVerificationDialog(
        context,
        e.challengeToken,
        rememberSession: _rememberSession,
      );
      if (verified && mounted) {
        _navigateAfterLogin();
        return;
      }
    } on AuthException catch (e) {
      setState(() => _errorText = e.message);
    }

    if (mounted) setState(() => _submitting = false);
  }

  void _navigateAfterLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => destinationForSession()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryYellow = Color(0xFFFFCC00);
    const Color darkGlass = Color(0x99121212); // Slightly more opaque glass
    const Color fieldBackground = Color(0x662C2C2C);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LoginBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: darkGlass,
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo Placeholder
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 120,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 120,
                                  width: 200,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    border: Border.all(
                                      color: primaryYellow,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.business,
                                        color: primaryYellow,
                                        size: 40,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Logo FN',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: primaryYellow,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32.0),

                          const Text(
                            'Bienvenido de nuevo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 32.0),

                          // Username Field
                          const Text(
                            'Usuario',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: _userController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: fieldBackground,
                              hintText: 'Ingresa tu usuario',
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Colors.white54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(
                                  color: primaryYellow,
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          // Password Field
                          const Text(
                            'Contraseña',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscureText,
                            onSubmitted: (_) => _submitting ? null : _submit(),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: fieldBackground,
                              hintText: '••••••••••',
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Colors.white54,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white54,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: const BorderSide(
                                  color: primaryYellow,
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          InkWell(
                            borderRadius: BorderRadius.circular(8.0),
                            onTap: () => setState(() => _rememberSession = !_rememberSession),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _rememberSession,
                                      onChanged: (value) => setState(() => _rememberSession = value ?? false),
                                      activeColor: primaryYellow,
                                      checkColor: Colors.black,
                                      side: const BorderSide(color: Colors.white54),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 10.0),
                                  const Text(
                                    'Recordar sesión',
                                    style: TextStyle(color: Colors.white70, fontSize: 14.0, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 12.0),
                            Text(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13.0, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 28.0),

                          // Login Button
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.0),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryYellow.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryYellow,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: primaryYellow.withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                elevation: 0,
                              ),
                              child: Center(
                                child: _submitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                      )
                                    : const Text(
                                        'INGRESAR',
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          // Forgot Password Link
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                );
                              },
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
