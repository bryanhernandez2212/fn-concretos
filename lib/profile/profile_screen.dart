import 'package:flutter/material.dart';
import '../main.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'mfa_screen.dart';

const _accentYellow = Color(0xFFFFCC00);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _firstName = 'Juan';
  String _lastName = 'Pérez';
  String _position = 'Representante de Ventas';
  String _plant = 'Planta Norte';
  String _city = 'Ciudad de México';
  String _email = 'usuario@fnconcretos.com';
  bool _notificationsEnabled = true;

  Future<void> _editProfile() async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          firstName: _firstName,
          lastName: _lastName,
          position: _position,
          plant: _plant,
          city: _city,
          email: _email,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (result['firstName']?.isNotEmpty ?? false) _firstName = result['firstName']!;
        if (result['lastName']?.isNotEmpty ?? false) _lastName = result['lastName']!;
        if (result['position']?.isNotEmpty ?? false) _position = result['position']!;
        if (result['plant']?.isNotEmpty ?? false) _plant = result['plant']!;
        if (result['city']?.isNotEmpty ?? false) _city = result['city']!;
        if (result['email']?.isNotEmpty ?? false) _email = result['email']!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);
    final onCardText = isDark ? Colors.white : Colors.black87;
    final onCardMuted = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55);

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, BottomNavBar.clearance(context) + 16),
      children: [
        // Profile summary — tap to edit
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorderColor),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _editProfile,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _accentYellow.withValues(alpha: 0.18),
                      child: const Icon(Icons.person, size: 30, color: _accentYellow),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_firstName $_lastName',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onCardText),
                          ),
                          const SizedBox(height: 2),
                          Text(_position, style: TextStyle(fontSize: 13, color: onCardMuted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: onCardMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Preferencias
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.notifications_none,
              iconColor: _accentYellow,
              title: 'Notificaciones',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) => setState(() => _notificationsEnabled = value),
              ),
            ),
            _SettingsTile(
              icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              iconColor: _accentYellow,
              title: 'Modo Oscuro',
              trailing: Switch(
                value: isDark,
                onChanged: (value) {
                  themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Datos personales
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.badge_outlined,
              iconColor: _accentYellow,
              title: 'Nombre',
              trailing: Text(_firstName, style: TextStyle(color: onCardMuted, fontSize: 14)),
            ),
            _SettingsTile(
              icon: Icons.badge_outlined,
              iconColor: _accentYellow,
              title: 'Apellido',
              trailing: Text(_lastName, style: TextStyle(color: onCardMuted, fontSize: 14)),
            ),
            _SettingsTile(
              icon: Icons.work_outline,
              iconColor: _accentYellow,
              title: 'Cargo',
              trailing: Text(_position, style: TextStyle(color: onCardMuted, fontSize: 14)),
            ),
            _SettingsTile(
              icon: Icons.factory_outlined,
              iconColor: _accentYellow,
              title: 'Planta',
              trailing: Text(_plant, style: TextStyle(color: onCardMuted, fontSize: 14)),
            ),
            _SettingsTile(
              icon: Icons.location_city_outlined,
              iconColor: _accentYellow,
              title: 'Ciudad',
              trailing: Text(_city, style: TextStyle(color: onCardMuted, fontSize: 14)),
            ),
            _SettingsTile(
              icon: Icons.mail_outline,
              iconColor: _accentYellow,
              title: 'Correo',
              trailing: Text(_email, style: TextStyle(color: onCardMuted, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Seguridad
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.lock_outline,
              iconColor: _accentYellow,
              title: 'Cambiar contraseña',
              trailing: Icon(Icons.chevron_right, color: onCardMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
              ),
            ),
            _SettingsTile(
              icon: Icons.shield_outlined,
              iconColor: _accentYellow,
              title: 'Verificación en dos pasos',
              trailing: Icon(Icons.chevron_right, color: onCardMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MfaScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Soporte
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.help_outline,
              iconColor: onCardMuted,
              title: 'Preguntas Frecuentes',
              trailing: Icon(Icons.chevron_right, color: onCardMuted),
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.description_outlined,
              iconColor: onCardMuted,
              title: 'Términos de Servicio',
              trailing: Icon(Icons.chevron_right, color: onCardMuted),
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              iconColor: onCardMuted,
              title: 'Política de Privacidad',
              trailing: Icon(Icons.chevron_right, color: onCardMuted),
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Cerrar sesión
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () async {
                await AuthService.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Cerrar Sesión',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded card that groups related [_SettingsTile]s together. Solid black
/// (bordered) in dark mode to stand out against the dark background; white
/// with a visible border in light mode so it doesn't read as a stray black box.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }
}

/// A single row inside a [_SettingsGroup]: icon, title, and optional
/// trailing content (switch, value text, or chevron).
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
