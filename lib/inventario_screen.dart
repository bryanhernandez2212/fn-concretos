import 'package:flutter/material.dart';
import 'placeholder_content.dart';

class InventarioScreen extends StatelessWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.inventory_2_outlined,
      title: 'Inventario',
      message: 'Aquí se gestionará el inventario disponible',
    );
  }
}
