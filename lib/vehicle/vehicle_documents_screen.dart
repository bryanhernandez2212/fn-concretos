import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/vehiculo.dart';
import 'vehicle_documents_widgets.dart';

/// Read-only list of the unit's real documents (`GET
/// /vehiculos/{vehiculoId}/documentos`), so the driver doesn't head out with
/// anything vencido. Uploading a new one isn't wired — `POST .../documentos`
/// needs `archivoUrl`, a pre-existing URL this app has no way to produce
/// (same blob-storage gap as `SignatureScreen`/`DeliveryPhotoScreen`) — and
/// this screen never had an upload affordance to begin with.
class VehicleDocumentsScreen extends StatefulWidget {
  final VehiculoResumen vehiculo;

  const VehicleDocumentsScreen({super.key, required this.vehiculo});

  @override
  State<VehicleDocumentsScreen> createState() => _VehicleDocumentsScreenState();
}

class _VehicleDocumentsScreenState extends State<VehicleDocumentsScreen> {
  late final Future<List<VehiculoDocumentoResumen>> _documentosFuture =
      OperacionesService.documentosVehiculo(widget.vehiculo.id);

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
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<VehiculoDocumentoResumen>>(
        future: _documentosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is AuthException ? error.message : 'No se pudieron cargar los documentos',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedColor),
                ),
              ),
            );
          }

          final documentos = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                '${widget.vehiculo.placas} · ${widget.vehiculo.marca} ${widget.vehiculo.modelo}'.trim(),
                style: TextStyle(fontSize: 13, color: mutedColor),
              ),
              const SizedBox(height: 16),
              if (documentos.isEmpty)
                Text('Este vehículo no tiene documentos registrados', style: TextStyle(color: mutedColor)),
              for (final documento in documentos) ...[
                DocumentCard(documento: documento, cardColor: cardColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}
