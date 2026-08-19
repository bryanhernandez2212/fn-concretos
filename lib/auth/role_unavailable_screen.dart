import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'roles.dart';

const _accentYellow = AppColors.accent;

/// Shown after a successful login when the account's role has no mobile
/// screens yet (only Operador de Olla/Bomba do — see [rolesConAppMovil]).
/// Rather than dropping an office-role user into the field-ops tabs, this
/// explains what their role is for and sends them back to log out.
class RoleUnavailableScreen extends StatelessWidget {
  const RoleUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rol = rolPorNombre(AuthService.rol);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _accentYellow.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smartphone_outlined, color: _accentYellow, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'Esta app aún no tiene pantallas para tu rol',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: textColor),
                ),
                const SizedBox(height: 12),
                if (rol != null) ...[
                  Text(
                    rol.nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _accentYellow),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rol.descripcion,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: mutedColor),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Por ahora la app móvil solo tiene pantallas para Operador de Olla, Operador de Bomba y Dirección. Usa el sistema de escritorio para las funciones de tu rol.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: mutedColor),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await AuthService.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
