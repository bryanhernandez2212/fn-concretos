import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/roles.dart';
import '../deliveries/turno_bombeo/turno_bombeo_screen.dart';
import '../profile/profile_screen.dart';
import '../deliveries/listado/deliveries_screen.dart';
import '../vehicle/vehicle_screen.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _navCompact = false;

  /// Operador de Bomba also gets the "Turno de bombeo" tab.
  final bool _esBomba = AuthService.rol == rolOperadorBomba;

  late final List<Widget> _pages = [
    const DeliveriesScreen(),
    if (_esBomba) const TurnoBombeoScreen(),
    const VehicleScreen(),
    const ProfileScreen(),
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
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const NavItem(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping,
            label: 'Entregas',
          ),
          if (_esBomba)
            const NavItem(
              icon: Icons.timer_outlined,
              selectedIcon: Icons.timer,
              label: 'Turno',
            ),
          const NavItem(
            icon: Icons.build_outlined,
            selectedIcon: Icons.build,
            label: 'Vehículo',
          ),
          const NavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
