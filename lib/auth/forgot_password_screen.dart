import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'forgot_password_widgets.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Two-step "olvidé mi contraseña" flow, pushed from [LoginScreen]:
/// step 0 asks for the account's correo and calls `forgot-password`; step 1
/// (reached once that succeeds) asks for the token from the email plus a
/// new password and calls `reset-password`.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0;
  bool _submitting = false;
  String? _errorText;
  String? _infoText;

  final _correoController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _correoController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestLink() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final message = await AuthService.forgotPassword(_correoController.text.trim());
      setState(() {
        _step = 1;
        _infoText = message;
      });
    } on AuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorText = 'Las contraseñas no coinciden');
      return;
    }
    if (_newPasswordController.text.length < 8) {
      setState(() => _errorText = 'La contraseña debe tener al menos 8 caracteres');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await AuthService.resetPassword(_tokenController.text.trim(), _newPasswordController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada, inicia sesión de nuevo')),
      );
    } on AuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _accentYellow.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_step == 0 ? Icons.mail_outline : Icons.lock_reset, color: _accentYellow, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          if (_step == 0) ..._buildRequestStep(context) else ..._buildResetStep(context),
          if (_infoText != null && _step == 1) ...[
            const SizedBox(height: 14),
            Text(_infoText!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            Text(_errorText!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : (_step == 0 ? _requestLink : _resetPassword),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentYellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                : Text(
                    _step == 0 ? 'Enviar enlace' : 'Restablecer contraseña',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRequestStep(BuildContext context) {
    return [
      const Text(
        'Ingresa el correo de tu cuenta y te enviaremos un enlace para restablecer tu contraseña.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FieldGroup(
        children: [
          AuthField(
            controller: _correoController,
            label: 'Correo',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildResetStep(BuildContext context) {
    return [
      const Text(
        'Pega el código que recibiste por correo y elige tu nueva contraseña.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FieldGroup(
        children: [
          AuthField(controller: _tokenController, label: 'Código de recuperación', icon: Icons.key_outlined),
          const SizedBox(height: 14),
          AuthField(
            controller: _newPasswordController,
            label: 'Nueva contraseña',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 14),
          AuthField(
            controller: _confirmPasswordController,
            label: 'Confirmar contraseña',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
        ],
      ),
    ];
  }
}
