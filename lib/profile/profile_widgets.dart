import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/notification_bell_button.dart';

const _accentYellow = AppColors.accent;

/// Rounded card that groups related [SettingsTile]s together. Solid black
/// (bordered) in dark mode to stand out against the dark background; white
/// with a visible border in light mode so it doesn't read as a stray black box.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({super.key, required this.children});

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

/// A single row inside a [SettingsGroup]: icon, title, and optional
/// trailing content (switch, value text, or chevron).
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
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


/// Top-of-profile card: avatar (tap to view the photo, or to pick one when
/// there's none yet; the camera badge always picks), name/puesto, and the
/// notification bell.
class ProfileHeaderCard extends StatelessWidget {
  final String? fotoUrl;
  final bool subiendoFoto;
  final String nombre;
  final String puesto;
  final VoidCallback onPickPhoto;
  final VoidCallback onViewPhoto;

  const ProfileHeaderCard({
    super.key,
    required this.fotoUrl,
    required this.subiendoFoto,
    required this.nombre,
    required this.puesto,
    required this.onPickPhoto,
    required this.onViewPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);
    final onCardText = isDark ? Colors.white : Colors.black87;
    final onCardMuted = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55);
    final fotoUrl = this.fotoUrl;
    final tieneFoto = fotoUrl != null && fotoUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: !tieneFoto ? onPickPhoto : onViewPhoto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _accentYellow.withValues(alpha: 0.18),
                    backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null,
                    child: !tieneFoto ? const Icon(Icons.person, size: 30, color: _accentYellow) : null,
                  ),
                  if (subiendoFoto)
                    const Positioned.fill(
                      child: CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _accentYellow),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: onPickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _accentYellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardColor, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onCardText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    puesto,
                    style: TextStyle(fontSize: 13, color: onCardMuted),
                  ),
                ],
              ),
            ),
            const NotificationBellButton(),
          ],
        ),
      ),
    );
  }
}

/// Muted value text used as a [SettingsTile]'s trailing content.
class SettingsValueText extends StatelessWidget {
  final String value;

  const SettingsValueText(this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onCardMuted = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55);
    return Text(value, style: TextStyle(color: onCardMuted, fontSize: 14));
  }
}

/// "Preferencias" group: notificaciones switch and the Apariencia tile.
/// [onAppearanceTap] receives the trailing control's own context so the
/// caller can anchor its overlay menu to it.
class PreferencesSettingsGroup extends StatelessWidget {
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final String themeModeLabel;
  final ValueChanged<BuildContext> onAppearanceTap;

  const PreferencesSettingsGroup({
    super.key,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.themeModeLabel,
    required this.onAppearanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onCardMuted = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55);

    return SettingsGroup(
      children: [
        SettingsTile(
          icon: Icons.notifications_none,
          iconColor: _accentYellow,
          title: 'Notificaciones',
          trailing: Switch(
            value: notificationsEnabled,
            onChanged: onNotificationsChanged,
          ),
        ),
        SettingsTile(
          icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          iconColor: _accentYellow,
          title: 'Apariencia',
          trailing: Builder(
            builder: (tileContext) => InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onAppearanceTap(tileContext),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      themeModeLabel,
                      style: TextStyle(color: onCardMuted, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, size: 18, color: onCardMuted),
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

/// "Datos personales" group. Each value falls back to '—' when null.
class PersonalDataSettingsGroup extends StatelessWidget {
  final String? usuario;
  final String? rol;
  final String? correo;
  final String? puesto;
  final String? area;
  final String? telefono;

  const PersonalDataSettingsGroup({
    super.key,
    required this.usuario,
    required this.rol,
    required this.correo,
    required this.puesto,
    required this.area,
    required this.telefono,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      children: [
        SettingsTile(
          icon: Icons.badge_outlined,
          iconColor: _accentYellow,
          title: 'Usuario',
          trailing: SettingsValueText(usuario ?? '—'),
        ),
        SettingsTile(
          icon: Icons.work_outline,
          iconColor: _accentYellow,
          title: 'Rol',
          trailing: SettingsValueText(rol ?? '—'),
        ),
        SettingsTile(
          icon: Icons.mail_outline,
          iconColor: _accentYellow,
          title: 'Correo',
          trailing: SettingsValueText(correo ?? '—'),
        ),
        SettingsTile(
          icon: Icons.badge_outlined,
          iconColor: _accentYellow,
          title: 'Puesto',
          trailing: SettingsValueText(puesto ?? '—'),
        ),
        SettingsTile(
          icon: Icons.apartment_outlined,
          iconColor: _accentYellow,
          title: 'Área',
          trailing: SettingsValueText(area ?? '—'),
        ),
        SettingsTile(
          icon: Icons.phone_outlined,
          iconColor: _accentYellow,
          title: 'Teléfono',
          trailing: SettingsValueText(telefono ?? '—'),
        ),
      ],
    );
  }
}

/// "Seguridad" group: optional biometric quick-login switch (only when
/// [biometriaDisponible]), change password, and MFA status.
class SecuritySettingsGroup extends StatelessWidget {
  final bool biometriaDisponible;
  final String biometriaTitulo;
  final bool cambiandoBiometria;
  final bool biometriaHabilitada;
  final ValueChanged<bool> onBiometriaChanged;
  final bool mfaHabilitado;
  final VoidCallback onChangePassword;
  final VoidCallback onMfa;

  const SecuritySettingsGroup({
    super.key,
    required this.biometriaDisponible,
    required this.biometriaTitulo,
    required this.cambiandoBiometria,
    required this.biometriaHabilitada,
    required this.onBiometriaChanged,
    required this.mfaHabilitado,
    required this.onChangePassword,
    required this.onMfa,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onCardMuted = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55);

    return SettingsGroup(
      children: [
        if (biometriaDisponible)
          SettingsTile(
            icon: Icons.face_retouching_natural,
            iconColor: _accentYellow,
            title: biometriaTitulo,
            trailing: cambiandoBiometria
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: biometriaHabilitada,
                    onChanged: onBiometriaChanged,
                  ),
          ),
        SettingsTile(
          icon: Icons.lock_outline,
          iconColor: _accentYellow,
          title: 'Cambiar contraseña',
          trailing: Icon(Icons.chevron_right, color: onCardMuted),
          onTap: onChangePassword,
        ),
        SettingsTile(
          icon: Icons.shield_outlined,
          iconColor: _accentYellow,
          title: 'Verificación en dos pasos',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mfaHabilitado ? 'Activada' : 'Desactivada',
                style: TextStyle(
                  color: mfaHabilitado ? AppColors.success : onCardMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.chevron_right, color: onCardMuted),
            ],
          ),
          onTap: onMfa,
        ),
      ],
    );
  }
}

/// "Soporte" group — FAQ/términos/privacidad, not wired to any content yet.
class SupportSettingsGroup extends StatelessWidget {
  const SupportSettingsGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onCardMuted = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55);

    return SettingsGroup(
      children: [
        SettingsTile(
          icon: Icons.help_outline,
          iconColor: onCardMuted,
          title: 'Preguntas Frecuentes',
          trailing: Icon(Icons.chevron_right, color: onCardMuted),
          onTap: () {},
        ),
        SettingsTile(
          icon: Icons.description_outlined,
          iconColor: onCardMuted,
          title: 'Términos de Servicio',
          trailing: Icon(Icons.chevron_right, color: onCardMuted),
          onTap: () {},
        ),
        SettingsTile(
          icon: Icons.privacy_tip_outlined,
          iconColor: onCardMuted,
          title: 'Política de Privacidad',
          trailing: Icon(Icons.chevron_right, color: onCardMuted),
          onTap: () {},
        ),
      ],
    );
  }
}

/// Pill-shaped "Cerrar Sesión" button at the bottom of the profile.
class LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const LogoutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: cardBorderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
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
    );
  }
}

// A translucent dropdown built directly as an Overlay entry (see
// `ProfileScreen`'s _showAppearanceMenu) rather than via PopupMenuButton — PopupMenuButton
// renders its content through its own Material/FadeTransition. No
// BackdropFilter/blur here: Impeller on iOS was rendering it as fully opaque
// instead of see-through, so this sticks to plain alpha compositing.
class AppearanceGlassMenu extends StatelessWidget {
  const AppearanceGlassMenu({super.key, required this.selectedMode, required this.onSelected});

  /// The currently active theme mode (`themeNotifier.value`), rendered bold/accented.
  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same surface colors as the rest of the app's cards (near-black in
    // dark mode, white in light mode) — an earlier "frosted glass" version
    // tinted this white-on-dark/black-on-light instead, which looked like
    // it wasn't respecting the theme at all.
    final panelColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.12);
    final textColor = isDark ? Colors.white : Colors.black87;

    Widget item(ThemeMode mode, IconData icon, String label) {
      final selected = selectedMode == mode;
      return InkWell(
        onTap: () => onSelected(mode),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? _accentYellow : textColor.withValues(alpha: 0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(ThemeMode.light, Icons.light_mode_outlined, 'Claro'),
              item(ThemeMode.dark, Icons.dark_mode_outlined, 'Oscuro'),
              item(ThemeMode.system, Icons.brightness_auto_outlined, 'Predeterminado del sistema'),
            ],
          ),
        ),
      ),
    );
  }
}
