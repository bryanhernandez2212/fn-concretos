import 'package:flutter/material.dart';
import 'pedidos_screen.dart';
import 'inventario_screen.dart';
import 'profile_screen.dart';
import 'placeholder_content.dart';
import 'striped_banner.dart';
import 'floating_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _titles = ['Inicio', 'Pedidos', 'Inventario', 'Perfil'];

  final List<Widget> _pages = const [
    _HomeContent(),
    PedidosScreen(),
    InventarioScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFCC00),
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8.0),
          child: StripedBanner(
            height: 8.0,
            color2: isDark ? Colors.black : const Color(0xFFD4A000),
          ),
        ),
      ),
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: FloatingNavBar(
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

// Contenido principal de la pestaña "Inicio"
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.dashboard_customize_outlined,
      title: 'Bienvenido al Panel Principal',
      message: 'Aquí irá el contenido de tu aplicación',
    );
  }
}
