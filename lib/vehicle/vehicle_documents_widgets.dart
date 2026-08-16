import 'package:flutter/material.dart';
import '../operaciones/vehiculo.dart';
import 'vehicle.dart';

class DocumentCard extends StatelessWidget {
  final VehiculoDocumentoResumen documento;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const DocumentCard({
    super.key,
    required this.documento,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final estado = estadoDeVigencia(documento.vigencia);
    final vigencia = documento.vigencia;
    final vigenciaTexto = vigencia == null
        ? 'Sin vigencia registrada'
        : 'Vigencia: ${vigencia.day.toString().padLeft(2, '0')}/${vigencia.month.toString().padLeft(2, '0')}/${vigencia.year}';

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
              color: estado.color.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.description_outlined, color: estado.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(documento.tipoDocumento, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 2),
                Text(vigenciaTexto, style: TextStyle(fontSize: 12.5, color: mutedColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: estado.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              estado.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: estado.color),
            ),
          ),
        ],
      ),
    );
  }
}
