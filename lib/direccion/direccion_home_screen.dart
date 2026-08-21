import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../profile/mfa_screen.dart';
import '../profile/profile_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'autorizaciones_screen.dart';
import 'rutas_activas_screen.dart';

const _accentYellow = AppColors.accent;

/// App shell for the Dirección role: Autorizaciones, Rutas activas (a
/// fleet-wide live map, not tied to any one pedido) and Perfil — vistas.md
/// only scopes Dirección's mobile screens to pedido credit authorization,
/// everything else in that role stays on desktop.
class DireccionHomeScreen extends StatefulWidget {
  const DireccionHomeScreen({super.key});

  @override
  State<DireccionHomeScreen> createState() => _DireccionHomeScreenState();
}

class _DireccionHomeScreenState extends State<DireccionHomeScreen> {
  int _currentIndex = 0;
  bool _navCompact = false;

  /// [RutasActivasScreen] embeds a real Google Maps platform view — unlike
  /// the other tabs, it's the one exception to "every tab stays mounted"
  /// below: a platform view composites through the native view hierarchy,
  /// not Flutter's own canvas, so fading it to opacity 0 while inactive
  /// doesn't reliably hide it (it can keep rendering, or bleed through onto
  /// whichever tab IS visible) the way it does for ordinary widgets.
  static const _rutasTabIndex = 1;

  final List<Widget> _pages = const [
    AutorizacionesScreen(),
    RutasActivasScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // The auth-service API docs mark MFA as mandatory for whoever can
    // authorize credit (Dirección), but login itself doesn't enforce it —
    // nudge once per session rather than assuming the backend already
    // blocked unenrolled accounts from reaching this screen.
    if (!AuthService.mfaHabilitado) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarAvisoMfa());
    }
  }

  Future<void> _mostrarAvisoMfa() async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65);

    final configurarAhora = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _accentYellow.withValues(alpha: 0.15)),
          child: const Icon(Icons.shield_outlined, color: _accentYellow, size: 28),
        ),
        title: Text(
          'Verificación en dos pasos requerida',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Tu rol requiere activar la verificación en dos pasos (MFA) para proteger la autorización de pedidos a crédito.',
          textAlign: TextAlign.center,
          style: TextStyle(color: mutedColor, fontSize: 13.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Más tarde', style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentYellow,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Configurar ahora', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (configurarAhora == true && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const MfaScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              final delta = notification.scrollDelta ?? 0;
              if (delta < 0 && !_navCompact) {
                setState(() => _navCompact = true);
              } else if (delta > 0 && _navCompact) {
                setState(() => _navCompact = false);
              }
            }
            return false;
          },
          child: Stack(
            fit: StackFit.expand,
            children: List.generate(_pages.length, (index) {
              final isActive = index == _currentIndex;
              // Actually unmount the map tab while it's not selected (see
              // `_rutasTabIndex` above) instead of just fading it out — this
              // also stops it polling GPS every 15s for a map nobody's
              // looking at.
              final content = (index == _rutasTabIndex && !isActive)
                  ? const SizedBox.shrink()
                  : _pages[index];
              return IgnorePointer(
                ignoring: !isActive,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  opacity: isActive ? 1.0 : 0.0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    scale: isActive ? 1.0 : 0.96,
                    child: content,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        compact: _navCompact,
        onTap: (int index) => setState(() => _currentIndex = index),
        items: const [
          NavItem(
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check,
            label: 'Autorizaciones',
          ),
          NavItem(
            icon: Icons.map_outlined,
            selectedIcon: Icons.map,
            label: 'Rutas',
          ),
          NavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
