import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/field_group.dart';
import 'change_password_widgets.dart';

const _accentYellow = AppColors.accent;

/// Authenticated change-password form, pushed from [ProfileScreen]'s
/// "Cambiar contraseña" settings tile.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _submitting = false;
  String? _errorText;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      await AuthService.changePassword(_currentPasswordController.text, _newPasswordController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, 'Contraseña actualizada');
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
        title: const Text('Cambiar contraseña'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
              child: const Icon(Icons.lock_outline, color: _accentYellow, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          FieldGroup(
            child: Column(
              children: [
                PasswordField(controller: _currentPasswordController, label: 'Contraseña actual'),
                const SizedBox(height: 14),
                PasswordField(controller: _newPasswordController, label: 'Nueva contraseña'),
                const SizedBox(height: 14),
                PasswordField(controller: _confirmPasswordController, label: 'Confirmar nueva contraseña'),
              ],
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            Text(_errorText!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
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
                : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
