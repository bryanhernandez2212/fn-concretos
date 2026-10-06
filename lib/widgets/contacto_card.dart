import 'package:flutter/material.dart';
import 'whatsapp_button.dart';

/// Card showing the specific person to reach for a delivery — the contacto
/// resolved from the obra↔cliente pairing (see
/// `ComercialService.contactoParaEntrega`), not a generic cliente-level
/// phone (a cliente has no single phone of its own; contacts are named
/// people, e.g. "Residente de obra" vs. "Compras"). Shared by
/// `direccion/PedidoDetailScreen` and `deliveries/DeliveryDetailScreen`,
/// since both need to show the same contacto to their respective user.
class ContactoCard extends StatelessWidget {
  final String nombre;
  final String? cargo;
  final String? telefono;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const ContactoCard({
    super.key,
    required this.nombre,
    this.cargo,
    this.telefono,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contacto en obra',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_outline, size: 20, color: mutedColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    if (cargo != null && cargo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(cargo!, style: TextStyle(fontSize: 12.5, color: mutedColor)),
                    ],
                    if (telefono != null && telefono!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(telefono!, style: TextStyle(fontSize: 13, color: textColor)),
                    ],
                  ],
                ),
              ),
              if (telefono != null && telefono!.isNotEmpty) ...[
                const SizedBox(width: 8),
                WhatsappButton(telefono: telefono!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
