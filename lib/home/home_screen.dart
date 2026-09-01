import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../deliveries/deliveries_screen.dart';
import '../vehicle/vehicle_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/notification_bell_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _navCompact = false;

  final List<Widget> _pages = const [
    DeliveriesScreen(),
    VehicleScreen(),
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
            // A dedicated row for the bell rather than floating it over the
            // tabs below — every tab draws its own header inline (e.g.
            // DeliveriesScreen's "Historial" button sits top-right too), so
            // an overlay would collide with those instead of this reserving
            // its own space.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(alignment: Alignment.centerRight, child: NotificationBellButton()),
            ),
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
        items: const [
          NavItem(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping,
            label: 'Entregas',
          ),
          NavItem(
            icon: Icons.build_outlined,
            selectedIcon: Icons.build,
            label: 'Vehículo',
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
