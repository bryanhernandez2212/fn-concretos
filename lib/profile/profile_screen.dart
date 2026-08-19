import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../administracion/administracion_service.dart';
import '../administracion/empleado.dart';
import '../deliveries/delivery_photo_widgets.dart';
import '../main.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../operaciones/operaciones_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/evidencia_viewer_screen.dart';
import 'change_password_screen.dart';
import 'mfa_screen.dart';
import 'profile_widgets.dart';

const _accentYellow = AppColors.accent;

/// Treats an empty/blank string as absent, so a field `administracion-service`
/// left blank falls back to '—' the same way a null one would.
String? _nombreOVacio(String? value) => (value == null || value.trim().isEmpty) ? null : value;

String _themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Claro';
    case ThemeMode.dark:
      return 'Oscuro';
    case ThemeMode.system:
      return 'Sistema';
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  OverlayEntry? _appearanceMenuEntry;
  EmpleadoResponse? _empleado;
  bool _subiendoFoto = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarEmpleado();
  }

  Future<void> _cargarEmpleado() async {
    final id = AuthService.idEmpleado;
    if (id == null) return;
    try {
      final empleado = await AdministracionService.obtenerEmpleado(id);
      if (mounted) setState(() => _empleado = empleado);
    } catch (_) {
      // Best-effort: the rest of the profile still works from AuthService's
      // session fields even if administracion-service is unreachable.
    }
  }

  Future<void> _pickPhoto() async {
    final empleado = _empleado;
    if (empleado == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const PhotoSourceSheet(),
    );
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;

      setState(() => _subiendoFoto = true);
      final bytes = await picked.readAsBytes();
      final path = picked.path.toLowerCase();
      final contentType = path.endsWith('.png')
          ? 'image/png'
          : (path.endsWith('.heic') ? 'image/heic' : 'image/jpeg');
      final extension = contentType.split('/').last;
      final nombreArchivo = 'perfil_${empleado.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final presigned = await AdministracionService.presignedUploadUrl(
        carpeta: 'empleado-fotos-perfil',
        nombreArchivo: nombreArchivo,
        contentType: contentType,
      );
      await OperacionesService.subirArchivoPresignado(presigned.uploadUrl, bytes, contentType);
      final actualizado = await AdministracionService.actualizarFotoPerfil(
        empleado.id,
        empleado,
        presigned.publicUrl,
      );
      if (mounted) setState(() => _empleado = actualizado);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnack.error(context, 'No se pudo acceder a la cámara/galería');
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  void _closeAppearanceMenu() {
    _appearanceMenuEntry?.remove();
    _appearanceMenuEntry = null;
  }

  void _showAppearanceMenu(BuildContext anchorContext) {
    final overlayState = Overlay.of(anchorContext);
    final anchorBox = anchorContext.findRenderObject()! as RenderBox;
    final overlayBox = overlayState.context.findRenderObject()! as RenderBox;
    final anchorTopRight = anchorBox.localToGlobal(
      anchorBox.size.topRight(Offset.zero),
      ancestor: overlayBox,
    );

    final entry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeAppearanceMenu,
              ),
            ),
            Positioned(
              left: anchorTopRight.dx - 240,
              top: anchorTopRight.dy + 6,
              width: 240,
              child: _AppearanceGlassMenu(
                onSelected: (mode) {
                  themeNotifier.value = mode;
                  _closeAppearanceMenu();
                },
              ),
            ),
          ],
        );
      },
    );
    _appearanceMenuEntry = entry;
    overlayState.insert(entry);
  }

  @override
  void dispose() {
    _closeAppearanceMenu();
    super.dispose();
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
        // Profile summary
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final fotoUrl = _empleado?.fotoPerfilUrl;
                    final tieneFoto = fotoUrl != null && fotoUrl.isNotEmpty;
                    return GestureDetector(
                      onTap: !tieneFoto
                          ? _pickPhoto
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => EvidenciaViewerScreen(url: fotoUrl, label: 'Foto de perfil'),
                                ),
                              );
                            },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: _accentYellow.withValues(alpha: 0.18),
                            backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null,
                            child: !tieneFoto
                                ? const Icon(Icons.person, size: 30, color: _accentYellow)
                                : null,
                          ),
                          if (_subiendoFoto)
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
                              onTap: _pickPhoto,
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
                    );
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombreOVacio(_empleado?.nombreCompleto) ?? AuthService.username ?? 'Usuario',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onCardText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _nombreOVacio(_empleado?.puestoNombre) ?? AuthService.rol ?? '',
                        style: TextStyle(fontSize: 13, color: onCardMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Preferencias
        SettingsGroup(
          children: [
            SettingsTile(
              icon: Icons.notifications_none,
              iconColor: _accentYellow,
              title: 'Notificaciones',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) => setState(() => _notificationsEnabled = value),
              ),
            ),
            SettingsTile(
              icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              iconColor: _accentYellow,
              title: 'Apariencia',
              trailing: Builder(
                builder: (tileContext) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showAppearanceMenu(tileContext),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _themeModeLabel(themeNotifier.value),
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
        ),
        const SizedBox(height: 20),

        // Datos personales — usuario/rol/correo vienen de la sesión real
        // (`AuthService`, poblado desde `GET /auth/me`). Nombre completo,
        // puesto, área y teléfono vienen de `administracion-service`'s
        // `GET /empleados/{id}` (ver `_cargarEmpleado`) — null mientras
        // carga o si ese servicio no respondió, así que cada fila cae de
        // vuelta a '—' en vez de inventar un dato.
        SettingsGroup(
          children: [
            SettingsTile(
              icon: Icons.badge_outlined,
              iconColor: _accentYellow,
              title: 'Usuario',
              trailing: Text(AuthService.username ?? '—', style: TextStyle(color: onCardMuted, fontSize: 14)),
            ),
            SettingsTile(
              icon: Icons.work_outline,
              iconColor: _accentYellow,
              title: 'Rol',
              trailing: Text(AuthService.rol ?? '—', style: TextStyle(color: onCardMuted, fontSize: 14)),
            ),
            SettingsTile(
              icon: Icons.mail_outline,
              iconColor: _accentYellow,
              title: 'Correo',
              trailing: Text(AuthService.correo ?? '—', style: TextStyle(color: onCardMuted, fontSize: 14)),
            ),
            SettingsTile(
              icon: Icons.badge_outlined,
              iconColor: _accentYellow,
              title: 'Puesto',
              trailing: Text(
                _nombreOVacio(_empleado?.puestoNombre) ?? '—',
                style: TextStyle(color: onCardMuted, fontSize: 14),
              ),
            ),
            SettingsTile(
              icon: Icons.apartment_outlined,
              iconColor: _accentYellow,
              title: 'Área',
              trailing: Text(
                _nombreOVacio(_empleado?.areaNombre) ?? '—',
                style: TextStyle(color: onCardMuted, fontSize: 14),
              ),
            ),
            SettingsTile(
              icon: Icons.phone_outlined,
              iconColor: _accentYellow,
              title: 'Teléfono',
              trailing: Text(
                _nombreOVacio(_empleado?.telefono) ?? '—',
                style: TextStyle(color: onCardMuted, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Seguridad
        SettingsGroup(
          children: [
            SettingsTile(
              icon: Icons.lock_outline,
              iconColor: _accentYellow,
              title: 'Cambiar contraseña',
              trailing: Icon(Icons.chevron_right, color: onCardMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
              ),
            ),
            SettingsTile(
              icon: Icons.shield_outlined,
              iconColor: _accentYellow,
              title: 'Verificación en dos pasos',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AuthService.mfaHabilitado ? 'Activada' : 'Desactivada',
                    style: TextStyle(
                      color: AuthService.mfaHabilitado ? AppColors.success : onCardMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: onCardMuted),
                ],
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MfaScreen()),
                );
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Soporte
        SettingsGroup(
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
        ),
        const SizedBox(height: 28),

        // Cerrar sesión
        Container(
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

// A translucent dropdown built directly as an Overlay entry (see
// _showAppearanceMenu above) rather than via PopupMenuButton — PopupMenuButton
// renders its content through its own Material/FadeTransition. No
// BackdropFilter/blur here: Impeller on iOS was rendering it as fully opaque
// instead of see-through, so this sticks to plain alpha compositing.
class _AppearanceGlassMenu extends StatelessWidget {
  const _AppearanceGlassMenu({required this.onSelected});

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
      final selected = themeNotifier.value == mode;
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
