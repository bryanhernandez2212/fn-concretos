import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../administracion/administracion_service.dart';
import '../administracion/empleado.dart';
import '../deliveries/delivery_photo_widgets.dart';
import '../main.dart';
import '../auth/auth_service.dart';
import '../auth/biometric_service.dart';
import '../auth/login_screen.dart';
import '../operaciones/operaciones_service.dart';
import '../widgets/app_feedback.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/evidencia_viewer_screen.dart';
import 'change_password_screen.dart';
import 'mfa_screen.dart';
import 'profile_widgets.dart';

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

  bool _biometriaDisponible = false;
  bool _cambiandoBiometria = false;

  @override
  void initState() {
    super.initState();
    _cargarEmpleado();
    _verificarBiometria();
  }

  Future<void> _verificarBiometria() async {
    final disponible = await BiometricService.disponible();
    if (mounted) setState(() => _biometriaDisponible = disponible);
  }

  Future<void> _cambiarBiometria(bool activar) async {
    setState(() => _cambiandoBiometria = true);
    try {
      if (activar) {
        final etiqueta = Platform.isIOS ? 'Face ID' : 'tu biometría';
        final autenticado = await BiometricService.autenticar('Confirma tu identidad para activar $etiqueta');
        if (!autenticado) {
          if (mounted) AppSnack.error(context, 'No se pudo verificar tu identidad');
          return;
        }
        await AuthService.habilitarBiometria();
      } else {
        await AuthService.deshabilitarBiometria();
      }
      if (mounted) setState(() {});
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } finally {
      if (mounted) setState(() => _cambiandoBiometria = false);
    }
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
        carpeta: 'empleados-fotos',
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
              child: AppearanceGlassMenu(
                selectedMode: themeNotifier.value,
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

  void _verFoto(String fotoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EvidenciaViewerScreen(url: fotoUrl, label: 'Foto de perfil'),
      ),
    );
  }

  Future<void> _abrirMfa() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MfaScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _cerrarSesion() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fotoUrl = _empleado?.fotoPerfilUrl;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, BottomNavBar.clearance(context) + 16),
      children: [
        // Profile summary
        ProfileHeaderCard(
          fotoUrl: fotoUrl,
          subiendoFoto: _subiendoFoto,
          nombre: _nombreOVacio(_empleado?.nombreCompleto) ?? AuthService.username ?? 'Usuario',
          puesto: _nombreOVacio(_empleado?.puestoNombre) ?? AuthService.rol ?? '',
          onPickPhoto: _pickPhoto,
          onViewPhoto: () => _verFoto(fotoUrl!),
        ),
        const SizedBox(height: 20),

        // Preferencias
        PreferencesSettingsGroup(
          notificationsEnabled: _notificationsEnabled,
          onNotificationsChanged: (value) => setState(() => _notificationsEnabled = value),
          themeModeLabel: _themeModeLabel(themeNotifier.value),
          onAppearanceTap: _showAppearanceMenu,
        ),
        const SizedBox(height: 20),

        // Datos personales — usuario/rol/correo vienen de la sesión real
        // (`AuthService`, poblado desde `GET /auth/me`). Nombre completo,
        // puesto, área y teléfono vienen de `administracion-service`'s
        // `GET /empleados/{id}` (ver `_cargarEmpleado`) — null mientras
        // carga o si ese servicio no respondió, así que cada fila cae de
        // vuelta a '—' en vez de inventar un dato.
        PersonalDataSettingsGroup(
          usuario: AuthService.username,
          rol: AuthService.rol,
          correo: AuthService.correo,
          puesto: _nombreOVacio(_empleado?.puestoNombre),
          area: _nombreOVacio(_empleado?.areaNombre),
          telefono: _nombreOVacio(_empleado?.telefono),
        ),
        const SizedBox(height: 20),

        // Seguridad
        SecuritySettingsGroup(
          biometriaDisponible: _biometriaDisponible,
          biometriaTitulo: Platform.isIOS ? 'Inicio rápido con Face ID' : 'Inicio rápido con biometría',
          cambiandoBiometria: _cambiandoBiometria,
          biometriaHabilitada: AuthService.biometricHabilitado,
          onBiometriaChanged: _cambiarBiometria,
          mfaHabilitado: AuthService.mfaHabilitado,
          onChangePassword: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
          ),
          onMfa: _abrirMfa,
        ),
        const SizedBox(height: 20),

        // Soporte
        const SupportSettingsGroup(),
        const SizedBox(height: 28),

        // Cerrar sesión
        LogoutButton(onTap: _cerrarSesion),
      ],
    );
  }
}
