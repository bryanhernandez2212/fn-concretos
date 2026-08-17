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
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}
