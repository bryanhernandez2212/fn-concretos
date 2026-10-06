import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'ollas/ollas_screen.dart';
import 'programacion/programacion_screen.dart';
import 'solicitudes/solicitudes_screen.dart';

/// App shell for the Jefe de Planta role: Programación, Ollas, Solicitudes
/// and Perfil. The three work tabs are still design-only (see
/// `jefe_planta_mock.dart`) until the endpoints are wired. Like
/// `AsesorComercialHomeScreen`, no tab embeds a native platform view, so
/// every tab stays mounted and cross-fades.
class JefePlantaHomeScreen extends StatefulWidget {
  const JefePlantaHomeScreen({super.key});

  @override
  State<JefePlantaHomeScreen> createState() => _JefePlantaHomeScreenState();
}

class _JefePlantaHomeScreenState extends State<JefePlantaHomeScreen> {
  int _currentIndex = 0;
  bool _navCompact = false;

  static const _pages = [
    ProgramacionScreen(),
    OllasScreen(),
    SolicitudesScreen(),
    ProfileScreen(),
  ];

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
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        compact: _navCompact,
        onTap: (int index) => setState(() => _currentIndex = index),
        items: const [
          NavItem(
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
            label: 'Programación',
          ),
          NavItem(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping,
            label: 'Ollas',
          ),
          NavItem(
            icon: Icons.request_quote_outlined,
            selectedIcon: Icons.request_quote,
            label: 'Solicitudes',
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
