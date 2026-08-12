import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Photo/evidence capture for a delivery, backed by `RemisionArchivo`.
/// "Tomar foto" / "Elegir de galería" are real — tapping either triggers
/// the OS's own camera/photo-library permission prompt automatically (via
/// `image_picker`), no manual in-app toggle asks first — but "Guardar
/// evidencia" stays a mock save: there's no upload endpoint documented for
/// RemisionArchivo yet, so the picked photos never leave the device.
class DeliveryPhotoScreen extends StatefulWidget {
  final String remisionFolio;

  const DeliveryPhotoScreen({super.key, required this.remisionFolio});

  @override
  State<DeliveryPhotoScreen> createState() => _DeliveryPhotoScreenState();
}

class _DeliveryPhotoScreenState extends State<DeliveryPhotoScreen> {
  final List<XFile> _photos = [];
  final _picker = ImagePicker();

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (source == null) return;

    try {
      final photo = await _picker.pickImage(source: source, imageQuality: 80);
      if (photo != null) setState(() => _photos.add(photo));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo acceder a la cámara/galería')),
      );
    }
  }

  void _removePhoto(XFile photo) {
    setState(() => _photos.remove(photo));
  }

  void _save() {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una foto')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evidencia guardada (demostración)')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);

    return Scaffold(
      appBar: AppBar(
        title: Text('Evidencia · ${widget.remisionFolio}'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Adjunta fotos de la descarga como evidencia de entrega',
            style: TextStyle(fontSize: 13.5, color: mutedColor),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              for (final photo in _photos)
                _PhotoThumb(
                  photo: photo,
                  borderColor: borderColor,
                  onRemove: () => _removePhoto(photo),
                ),
              _AddPhotoTile(borderColor: borderColor, mutedColor: mutedColor, onTap: _addPhoto),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Guardar evidencia', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet offering "Tomar foto" (camera) or "Elegir de galería"
/// (existing files), returning the chosen [ImageSource] or null if
/// dismissed.
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _accentYellow),
              title: Text('Tomar foto', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _accentYellow),
              title: Text('Elegir de galería', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

/// A real picked photo, shown as its actual thumbnail with a delete
/// button overlay.
class _PhotoThumb extends StatelessWidget {
  final XFile photo;
  final Color borderColor;
  final VoidCallback onRemove;

  const _PhotoThumb({
    required this.photo,
    required this.borderColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: borderColor)),
            child: Image.file(File(photo.path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final Color borderColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _AddPhotoTile({required this.borderColor, required this.mutedColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: DottedBorderBox(
          borderColor: borderColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_outlined, color: mutedColor, size: 28),
              const SizedBox(height: 6),
              Text('Agregar foto', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: mutedColor)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded box with a dashed outline, used to invite adding new content.
class DottedBorderBox extends StatelessWidget {
  final Color borderColor;
  final Widget child;

  const DottedBorderBox({super.key, required this.borderColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: borderColor),
      child: Container(
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}
