import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';
import '../../asesor_comercial/asesor_comercial_home_screen.dart';
import '../../asesor_comercial/asesor_comercial_service.dart';
import '../../comercial/comercial_service.dart';
import '../../direccion/direccion_home_screen.dart';
import '../../home/home_screen.dart';
import '../../jefe_planta/jefe_planta_home_screen.dart';
import '../../theme/app_colors.dart';
import '../auth_service.dart';
import '../recuperar_password/forgot_password_screen.dart';
import 'mfa_verification_dialog.dart';
import '../role_unavailable_screen.dart';
import '../roles.dart';

Widget destinationForSession() {
  if (rolesConAppMovil.contains(AuthService.rol)) {
    return const HomeScreen();
  } else if (AuthService.permisos.contains(permisoAutorizarCredito)) {
    return const DireccionHomeScreen();
  } else if (AuthService.permisos.contains(permisoAutorizarLogistica)) {
    // Jefe de Planta. Checked after Dirección so a Dirección account that
    // also holds this permission keeps its own shell.
    return const JefePlantaHomeScreen();
  } else if (AuthService.permisos.contains(permisoAdministrarAgenda)) {
    return const AsesorComercialHomeScreen();
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const Color darkSurface = Color(0xFF16181B);
    const Color fieldBackground = Color(0xFF22252A);

    return Scaffold(
      backgroundColor: darkSurface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fondo superior con la imagen de FN Concretos
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Imagen extendida hacia abajo para traslaparse detrás de las esquinas curvas
                Positioned(
                  top: -70,
                  left: 0,
                  right: 0,
                  bottom: -40,
                  child: Image.asset(
                    'assets/images/login.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
                // Gradiente superior para visibilidad de la barra de estado
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 90,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Formulario compacto de ancho completo (sin scroll)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: darkSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24.0),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              24.0,
              20.0,
              24.0,
              16.0 + bottomPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título de bienvenida
                const Text(
                  'Bienvenido de nuevo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Campo Usuario
                const Text(
                  'Usuario',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6.0),
                TextField(
                  controller: _userController,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 12.0,
                    ),
                    filled: true,
                    fillColor: fieldBackground,
                    hintText: 'Ingresa tu usuario',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Colors.white54,
                      size: 20.0,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),

                // Campo Contraseña
                const Text(
                  'Contraseña',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6.0),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  onSubmitted: (_) => _submitting ? null : _submit(),
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 12.0,
                    ),
                    filled: true,
                    fillColor: fieldBackground,
                    hintText: '••••••••••',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.white54,
                      size: 20.0,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                    suffixIcon: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 42,
                        minHeight: 42,
                      ),
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white54,
                        size: 20.0,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),

                // Recordar sesión
                InkWell(
                  borderRadius: BorderRadius.circular(6.0),
                  onTap: () =>
                      setState(() => _rememberSession = !_rememberSession),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberSession,
                            onChanged: (value) => setState(
                              () => _rememberSession = value ?? false,
                            ),
                            activeColor: AppColors.accent,
                            checkColor: Colors.black,
                            side: const BorderSide(color: Colors.white54),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        const Text(
                          'Recordar sesión',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Error text
                if (_errorText != null) ...[
                  const SizedBox(height: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14.0),

                // Botón de Login
                Container(
                  height: 48.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AppColors.accent.withValues(
                        alpha: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      elevation: 0,
                    ),
                    child: Center(
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'INGRESAR',
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 6.0),

                // Enlace Olvidé contraseña
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 6.0,
                      ),
                    ),
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Link(
                    uri: Uri.parse("https://solucionesws.com"),
                    builder: (context, followLink) => InkWell(
                      onTap: followLink,
                      borderRadius: BorderRadius.circular(6.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 6.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Desarrollado por Soluciones WS",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Container(
                              height: 1.5,
                              width: 180.0,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
