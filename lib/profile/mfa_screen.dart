import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'mfa_widgets.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Enrolls the current session in TOTP-based MFA, pushed from
/// [ProfileScreen]'s "Verificación en dos pasos" settings tile.
///
/// Step 0: request a secret from `/auth/mfa/enable`.
/// Step 1: show that secret (no QR-code renderer wired up, so it's shown as
/// selectable text) and collect the 6-digit code to confirm activation.
class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key});

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  bool _submitting = false;
  String? _errorText;
  MfaEnrollment? _enrollment;
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _generateSecret() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final enrollment = await AuthService.enableMfa();
      setState(() => _enrollment = enrollment);
    } on AuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await AuthService.confirmMfaEnable(_codeController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verificación en dos pasos activada')),
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
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6);
    final enrollment = _enrollment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación en dos pasos'),
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
              child: const Icon(Icons.shield_outlined, color: _accentYellow, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          if (enrollment == null) ...[
            Text(
              'Genera un código secreto y agrégalo a tu app autenticadora (Google Authenticator, Authy, etc.) para proteger tu cuenta con un segundo factor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor),
            ),
          ] else ...[
            Text(
              'Copia este código en tu app autenticadora, luego ingresa el código de 6 dígitos que genere para confirmar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor),
            ),
            const SizedBox(height: 20),
            SecretCard(secret: enrollment.secret, textColor: textColor, mutedColor: mutedColor),
            const SizedBox(height: 20),
            FieldGroup(
              children: [
                TextField(
                  controller: _codeController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: TextStyle(color: textColor, letterSpacing: 4, fontSize: 20),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            Text(_errorText!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : (enrollment == null ? _generateSecret : _confirm),
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
                    enrollment == null ? 'Generar código' : 'Activar',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}

