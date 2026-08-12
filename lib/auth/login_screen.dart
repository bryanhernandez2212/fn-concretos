import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../direccion/comercial_service.dart';
import '../direccion/direccion_home_screen.dart';
import '../home/home_screen.dart';
import 'auth_service.dart';
import 'forgot_password_screen.dart';
import 'role_unavailable_screen.dart';
import 'roles.dart';

const _accentYellow = Color(0xFFFFCC00);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
  bool _submitting = false;
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
      await AuthService.login(_userController.text.trim(), _passwordController.text);
      if (!mounted) return;
      _navigateAfterLogin();
      return;
    } on MfaRequiredException catch (e) {
      final verified = await _showMfaDialog(e.challengeToken);
      if (verified && mounted) {
        _navigateAfterLogin();
        return;
      }
    } on AuthException catch (e) {
      setState(() => _errorText = e.message);
    }

    if (mounted) setState(() => _submitting = false);
  }

  /// Field operators (see [rolesConAppMovil]) go to [HomeScreen] by role
  /// name — that pair of roles is hardcoded in this build regardless of
  /// permissions. Everyone else is routed by *permission*, not role name:
  /// whoever holds `pedidos.autorizar_credito` gets [DireccionHomeScreen],
  /// since the backend's roles-controller lets that permission move to a
  /// different or renamed role independently of this app. No mobile
  /// screens exist for anyone else yet, so they see [RoleUnavailableScreen].
  void _navigateAfterLogin() {
    final Widget destination;
    if (rolesConAppMovil.contains(AuthService.rol)) {
      destination = const HomeScreen();
    } else if (AuthService.permisos.contains(permisoAutorizarCredito)) {
      destination = const DireccionHomeScreen();
    } else {
      destination = const RoleUnavailableScreen();
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  /// Shows the TOTP-code prompt for accounts with MFA enabled. Returns
  /// whether the code was verified successfully.
  Future<bool> _showMfaDialog(String challengeToken) async {
    final codeController = TextEditingController();
    String? dialogError;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Verificación en dos pasos', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingresa el código de 6 dígitos de tu app autenticadora',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, letterSpacing: 4, fontSize: 20),
                    decoration: const InputDecoration(counterText: ''),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _accentYellow, foregroundColor: Colors.black),
                  onPressed: () async {
                    try {
                      await AuthService.verifyMfa(challengeToken, codeController.text.trim());
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                    } on AuthException catch (e) {
                      setDialogState(() => dialogError = e.message);
                    }
                  },
                  child: const Text('Verificar'),
                ),
              ],
            );
          },
        );
      },
    );

    return verified ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryYellow = Color(0xFFFFCC00);
    const Color darkGlass = Color(0x99121212); // Slightly more opaque glass
    const Color fieldBackground = Color(0x662C2C2C);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _FallingSquaresBackground()),
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
                          if (_errorText != null) ...[
                            const SizedBox(height: 20.0),
                            Text(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13.0, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 40.0),

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

/// Pure-design login background: a checkered grid of white lines drifting
/// diagonally toward the bottom-right corner, plus small white and yellow
/// dots drifting upward, over solid black. Replaces the old background
/// image asset.
class _FallingSquaresBackground extends StatefulWidget {
  const _FallingSquaresBackground();

  @override
  State<_FallingSquaresBackground> createState() => _FallingSquaresBackgroundState();
}

class _FallingSquaresBackgroundState extends State<_FallingSquaresBackground>
    with TickerProviderStateMixin {
  static const _gridSize = 46.0;
  late final AnimationController _gridController;
  late final AnimationController _dotsController;
  final _random = math.Random();
  late final List<_Dot> _dots = List.generate(55, (_) => _Dot.random(_random));

  @override
  void initState() {
    super.initState();
    _gridController = AnimationController(vsync: this, duration: const Duration(seconds: 11))..repeat();
    _dotsController = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(() {
        for (final dot in _dots) {
          dot.advance(_random);
        }
      })
      ..repeat();
  }

  @override
  void dispose() {
    _gridController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: Listenable.merge([_gridController, _dotsController]),
        builder: (context, _) => CustomPaint(
          painter: _BackgroundPainter(
            gridOffset: _gridController.value * _gridSize,
            gridSize: _gridSize,
            dots: _dots,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Draws the drifting grid lines first, then the drifting dots on top.
class _BackgroundPainter extends CustomPainter {
  final double gridOffset;
  final double gridSize;
  final List<_Dot> dots;

  _BackgroundPainter({required this.gridOffset, required this.gridSize, required this.dots});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (double x = gridOffset - gridSize; x < size.width + gridSize; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = gridOffset - gridSize; y < size.height + gridSize; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final dot in dots) {
      dotPaint.color = dot.color.withValues(alpha: dot.opacity);
      canvas.drawCircle(Offset(dot.x * size.width, dot.y * size.height), dot.radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) => true;
}

/// A single dot drifting upward; position is stored as a fraction (0..1)
/// of the canvas so it scales with any screen size. Resets just below the
/// bottom edge once it drifts past the top, so the upward flow is
/// continuous.
class _Dot {
  double x;
  double y;
  final double radius;
  final double speed;
  final double opacity;
  final Color color;

  _Dot({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
    required this.color,
  });

  factory _Dot.random(math.Random random) {
    return _Dot(
      x: random.nextDouble(),
      y: random.nextDouble(),
      radius: 1.5 + random.nextDouble() * 3,
      speed: 0.0004 + random.nextDouble() * 0.0011,
      opacity: 0.25 + random.nextDouble() * 0.55,
      color: random.nextBool() ? Colors.white : _accentYellow,
    );
  }

  void advance(math.Random random) {
    y -= speed;
    if (y < -0.05) {
      y = 1 + random.nextDouble() * 0.2;
      x = random.nextDouble();
    }
  }
}

