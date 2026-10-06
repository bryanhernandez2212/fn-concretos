import 'package:flutter/material.dart';
import '../operaciones/vehiculo.dart';
import '../theme/app_colors.dart';
import '../widgets/evidencia_viewer_screen.dart';
import 'vehicle.dart';

/// Full detail for one pendiente — tipo, descripción, fechas, and evidencia
/// photos (`evidenciaApertura`/`evidenciaCierre`) shown full-width instead
/// of squeezed into the list card. Each photo is tappable to zoom.
class VehiclePendienteDetailScreen extends StatelessWidget {
  final VehiculoPendienteResumen pendiente;

  const VehiclePendienteDetailScreen({super.key, required this.pendiente});

  static String _fecha(DateTime? d) =>
      d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.12);

    final resuelto = pendiente.fechaResolucion != null;
    final color = resuelto ? AppColors.success : AppColors.warning;
    final tipo = TipoPendiente.values.where((t) => t.backendValue == pendiente.tipoPendiente);
    final tipoLabel = tipo.isEmpty ? pendiente.tipoPendiente : tipo.first.label;
    final tipoIcon = tipo.isEmpty ? Icons.report_problem_outlined : tipo.first.icon;

    return Scaffold(
      appBar: AppBar(
        title: Text(tipoLabel),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
                child: Icon(tipoIcon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tipoLabel, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        resuelto ? 'Resuelto' : 'Abierto',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _DetailSection(
            label: 'Descripción',
            textColor: textColor,
            child: Text(
              pendiente.descripcion.isEmpty ? 'Sin descripción' : pendiente.descripcion,
              style: TextStyle(fontSize: 14, color: pendiente.descripcion.isEmpty ? mutedColor : textColor),
            ),
          ),
          const SizedBox(height: 20),
          _DetailSection(
            label: 'Fechas',
            textColor: textColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reportado: ${_fecha(pendiente.fechaDeteccion)}', style: TextStyle(fontSize: 14, color: textColor)),
                if (resuelto) ...[
                  const SizedBox(height: 4),
                  Text('Resuelto: ${_fecha(pendiente.fechaResolucion)}', style: TextStyle(fontSize: 14, color: textColor)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DetailSection(
            label: 'Evidencia del reporte',
            textColor: textColor,
            child: pendiente.evidenciaApertura == null
                ? Text('Sin evidencia', style: TextStyle(fontSize: 13, color: mutedColor))
                : _EvidenciaPhoto(url: pendiente.evidenciaApertura!, label: 'Evidencia del reporte', borderColor: borderColor, cardColor: cardColor),
          ),
          if (resuelto) ...[
            const SizedBox(height: 20),
            _DetailSection(
              label: 'Evidencia de resolución',
              textColor: textColor,
              child: pendiente.evidenciaCierre == null
                  ? Text('Sin evidencia', style: TextStyle(fontSize: 13, color: mutedColor))
                  : _EvidenciaPhoto(url: pendiente.evidenciaCierre!, label: 'Evidencia de resolución', borderColor: borderColor, cardColor: cardColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String label;
  final Color textColor;
  final Widget child;

  const _DetailSection({required this.label, required this.textColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: textColor.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Full-width, tappable evidencia photo — both `evidenciaApertura`/
/// `evidenciaCierre` are already-public R2 URLs, so `Image.network` loads
/// them directly with no auth needed.
class _EvidenciaPhoto extends StatelessWidget {
  final String url;
  final String label;
  final Color borderColor;
  final Color cardColor;

  const _EvidenciaPhoto({required this.url, required this.label, required this.borderColor, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EvidenciaViewerScreen(url: url, label: label),
            fullscreenDialog: true,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(color: cardColor, border: Border.all(color: borderColor)),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            },
            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_outlined, size: 32)),
          ),
        ),
      ),
    );
  }
}
