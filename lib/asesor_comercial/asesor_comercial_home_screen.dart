import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'asesor_comercial_service.dart';
import 'comisiones_screen.dart';
import 'cotizaciones_screen.dart';
import 'visitas_screen.dart';

/// App shell for the Asesor Comercial role: Visitas, Cotizaciones,
/// Comisiones and Perfil. There used to be an "Agenda" tab too, dropped
/// since there was nothing to do there — no screen ever created an `AgendaActividad`, the
/// tab only ever listed/marked existing ones (and nothing populated it
/// either), so it was a dead end rather than a useful view; `Visita`
/// scheduling now covers the "what am I doing today/next" need this role
/// actually has. No MFA nudge here (unlike `DireccionHomeScreen`) — this
/// role has no documented backend MFA requirement. No tab embeds a native
/// platform view, so — also unlike `DireccionHomeScreen` — every tab just
/// stays mounted and cross-fades, no unmount-while-inactive exception
/// needed.
///
/// The Comisiones tab hides itself when `GET /asesores/me` answers 404 (the
/// account holds this role's permission but has no asesor record linked,
/// so there's no `asesorId` to query commissions with). It starts shown,
/// since that's the expected case, and only disappears on a confirmed 404 —
/// a network error keeps it, letting the tab's own error state offer retry.
class AsesorComercialHomeScreen extends StatefulWidget {
  const AsesorComercialHomeScreen({super.key});

  @override
  State<AsesorComercialHomeScreen> createState() => _AsesorComercialHomeScreenState();
}

class _AsesorComercialHomeScreenState extends State<AsesorComercialHomeScreen> {
  int _currentIndex = 0;
  bool _navCompact = false;
  bool _mostrarComisiones = true;

  static const _comisionesIndex = 2;

  @override
  void initState() {
    super.initState();
    _verificarAsesor();
  }

  Future<void> _verificarAsesor() async {
    try {
      final asesor = await AsesorComercialService.miAsesor();
      if (asesor != null || !mounted) return;
      setState(() {
        _mostrarComisiones = false;
        // Keep the same tab selected once Comisiones drops out of the list.
        if (_currentIndex == _comisionesIndex) {
          _currentIndex = 0;
        } else if (_currentIndex > _comisionesIndex) {
          _currentIndex--;
        }
      });
    } catch (_) {
      // Leave the tab in place; it surfaces its own error with a retry.
    }
  }

  List<Widget> get _pages => [
    const VisitasScreen(),
    const CotizacionesScreen(),
    if (_mostrarComisiones) const ComisionesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
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
                  children: List.generate(pages.length, (index) {
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
                          child: pages[index],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        compact: _navCompact,
        onTap: (int index) => setState(() => _currentIndex = index),
        items: [
          const NavItem(icon: Icons.place_outlined, selectedIcon: Icons.place, label: 'Visitas'),
          const NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Cotizaciones'),
          if (_mostrarComisiones)
            const NavItem(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet,
              label: 'Comisiones',
            ),
          const NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Perfil'),
        ],
      ),
    );
  }
}
