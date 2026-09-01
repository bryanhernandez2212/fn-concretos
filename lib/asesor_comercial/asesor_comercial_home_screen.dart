import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'agenda_screen.dart';
import 'cotizaciones_screen.dart';
import 'visitas_screen.dart';

/// App shell for the Asesor Comercial role: Agenda, Visitas, Cotizaciones
/// and Perfil. No MFA nudge here (unlike `DireccionHomeScreen`) — this role
/// has no documented backend MFA requirement. No tab embeds a native
/// platform view, so — also unlike `DireccionHomeScreen` — every tab just
/// stays mounted and cross-fades, no unmount-while-inactive exception
/// needed.
class AsesorComercialHomeScreen extends StatefulWidget {
  const AsesorComercialHomeScreen({super.key});

  @override
  State<AsesorComercialHomeScreen> createState() => _AsesorComercialHomeScreenState();
}

class _AsesorComercialHomeScreenState extends State<AsesorComercialHomeScreen> {
  int _currentIndex = 0;
  bool _navCompact = false;

  final List<Widget> _pages = const [
    AgendaScreen(),
    VisitasScreen(),
    CotizacionesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        compact: _navCompact,
        onTap: (int index) => setState(() => _currentIndex = index),
        items: const [
          NavItem(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month, label: 'Agenda'),
          NavItem(icon: Icons.place_outlined, selectedIcon: Icons.place, label: 'Visitas'),
          NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Cotizaciones'),
          NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Perfil'),
        ],
      ),
    );
  }
}
