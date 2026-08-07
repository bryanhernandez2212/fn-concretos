import 'package:flutter/material.dart';
import '../widgets/placeholder_content.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.inventory_2_outlined,
      title: 'Inventario',
      message: 'Aquí se gestionará el inventario disponible',
    );
  }
}
