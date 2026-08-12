import 'package:flutter/material.dart';
import 'vehicle.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Read-only list of the unit's documents (`VehiculoSeguro`/
/// `VehiculoDocumento`) and their expiration, so the driver doesn't head
/// out with anything vencido.
class VehicleDocumentsScreen extends StatelessWidget {
  const VehicleDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos del Vehículo'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            '$vehiculoPlaca · $vehiculoModelo',
            style: TextStyle(fontSize: 13, color: mutedColor),
          ),
          const SizedBox(height: 16),
          for (final documento in vehiculoDocumentos) ...[
            _DocumentCard(documento: documento, cardColor: cardColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final VehiculoDocumento documento;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _DocumentCard({
    required this.documento,
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: documento.estado.color.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.description_outlined, color: documento.estado.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(documento.nombre, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 2),
                Text('Vigencia: ${documento.vigencia}', style: TextStyle(fontSize: 12.5, color: mutedColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: documento.estado.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              documento.estado.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: documento.estado.color),
            ),
          ),
        ],
      ),
    );
  }
}
