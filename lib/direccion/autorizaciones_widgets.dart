import 'package:flutter/material.dart';
import 'pedido.dart';

class PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const PedidoCard({
    super.key,
    required this.pedido,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(pedido.obraNombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                  ),
                  Text(pedido.folio, style: TextStyle(fontSize: 12, color: mutedColor)),
                ],
              ),
              const SizedBox(height: 4),
              Text(pedido.clienteNombre, style: TextStyle(fontSize: 13, color: mutedColor)),
              const SizedBox(height: 10),
              Row(
                children: [
                  InfoPill(icon: Icons.water_drop_outlined, text: '${pedido.volumenSolicitadoM3} m³', mutedColor: mutedColor, textColor: textColor),
                  const SizedBox(width: 8),
                  InfoPill(icon: Icons.payments_outlined, text: pedido.condicionPago, mutedColor: mutedColor, textColor: textColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color mutedColor;
  final Color textColor;

  const InfoPill({super.key, required this.icon, required this.text, required this.mutedColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: mutedColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Color mutedColor;

  const EmptyState({super.key, required this.cardColor, required this.borderColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Icon(Icons.task_alt, color: mutedColor, size: 28),
          const SizedBox(height: 10),
          Text('No hay pedidos pendientes de autorizar', style: TextStyle(fontSize: 13.5, color: mutedColor), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color cardColor;
  final Color borderColor;
  final Color mutedColor;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    required this.cardColor,
    required this.borderColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(fontSize: 13.5, color: mutedColor), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
