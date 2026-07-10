import 'package:flutter/material.dart';
import 'placeholder_content.dart';

class PedidosScreen extends StatelessWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.receipt_long_outlined,
      title: 'Pedidos',
      message: 'Aquí se mostrará el listado de pedidos',
    );
  }
}
