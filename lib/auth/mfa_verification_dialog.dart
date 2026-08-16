import 'package:flutter/material.dart';
import 'auth_service.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Shows the TOTP-code prompt for accounts with MFA enabled. Returns
/// whether the code was verified successfully.
Future<bool> showMfaVerificationDialog(BuildContext context, String challengeToken) async {
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
