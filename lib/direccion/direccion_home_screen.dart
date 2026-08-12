import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'autorizaciones_screen.dart';

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
