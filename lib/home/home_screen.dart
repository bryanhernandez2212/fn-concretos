import 'package:flutter/material.dart';
import '../orders/orders_screen.dart';
import '../inventory/inventory_screen.dart';
import '../profile/profile_screen.dart';
import 'dashboard_content.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardContent(),
    OrdersScreen(),
    InventoryScreen(),
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
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          NavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Inicio',
          ),
          NavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: 'Pedidos',
          ),
          NavItem(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2,
            label: 'Inventario',
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

