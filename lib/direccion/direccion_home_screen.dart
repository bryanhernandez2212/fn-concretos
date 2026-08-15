import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../profile/mfa_screen.dart';
import '../profile/profile_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'autorizaciones_screen.dart';

const _accentYellow = Color(0xFFFFCC00);

/// App shell for the Dirección role: just Autorizaciones + Perfil for now —
/// vistas.md only scopes Dirección's mobile screens to pedido credit
/// authorization, everything else in that role stays on desktop.
class DireccionHomeScreen extends StatefulWidget {
  const DireccionHomeScreen({super.key});

  @override
  State<DireccionHomeScreen> createState() => _DireccionHomeScreenState();
}

class _DireccionHomeScreenState extends State<DireccionHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    AutorizacionesScreen(),
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
    final configurarAhora = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.shield_outlined, color: _accentYellow, size: 32),
        title: const Text('Verificación en dos pasos requerida'),
        content: const Text(
          'Tu rol requiere activar la verificación en dos pasos (MFA) para proteger la autorización de pedidos a crédito.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Más tarde')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Configurar ahora')),
        ],
      ),
    );
    if (configurarAhora == true && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MfaScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: List.generate(_pages.length, (index) {
            final isActive = index == _currentIndex;
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
                  child: _pages[index],
                ),
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (int index) => setState(() => _currentIndex = index),
        items: const [
          NavItem(
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check,
            label: 'Autorizaciones',
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
