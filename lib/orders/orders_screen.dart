import 'package:flutter/material.dart';
import '../widgets/placeholder_content.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.receipt_long_outlined,
      title: 'Pedidos',
      message: 'Aquí se mostrará el listado de pedidos',
    );
  }
}
