import 'package:flutter/material.dart';
import '../operaciones/evidencia.dart';
import 'delivery_detail_widgets.dart';

/// Read-only gallery of the photo evidence already attached to a remisión —
/// opened instead of [DeliveryPhotoScreen] once more than one photo exists,
/// same idea as tapping "Firma digital de entrega" to view an existing
/// firma instead of reopening the signature pad (a single existing photo
/// skips this screen and opens `EvidenciaViewerScreen` directly, same as
/// firma).
class EvidenciaFotosScreen extends StatelessWidget {
  final String remisionFolio;
  final List<ArchivoResponse> archivos;

  const EvidenciaFotosScreen({super.key, required this.remisionFolio, required this.archivos});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.12);

    return Scaffold(
      appBar: AppBar(
        title: Text('Evidencia · $remisionFolio'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            '${archivos.length} fotos guardadas',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: mutedColor, letterSpacing: 0.3),
          ),
          const SizedBox(height: 10),
          EvidenciaThumbnailStrip(archivos: archivos, borderColor: borderColor),
        ],
      ),
    );
  }
}
