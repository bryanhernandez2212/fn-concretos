import 'package:flutter/material.dart';

/// Full-screen zoomable view for a single evidencia photo — a plain
/// already-public R2 URL from the presigned-upload flow used across
/// `SignatureScreen`, `DeliveryPhotoScreen`, and `VehiclePendingScreen`, so
/// it's shared here rather than duplicated per feature.
class EvidenciaViewerScreen extends StatelessWidget {
  final String url;
  final String label;

  const EvidenciaViewerScreen({super.key, required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(label),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: url.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay una URL guardada para esta evidencia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : InteractiveViewer(
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(color: Colors.white54);
                  },
                  errorBuilder: (context, error, stackTrace) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                        const SizedBox(height: 12),
                        // TEMP debug: surface the URL that failed so we can
                        // tell a bad/empty save apart from a real network/
                        // decode error without needing device logs.
                        Text(
                          'No se pudo cargar:\n$url',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
