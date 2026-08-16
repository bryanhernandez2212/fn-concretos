import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'delivery_photo_widgets.dart';

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
      builder: (context) => const PhotoSourceSheet(),
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
                PhotoThumb(
                  photo: photo,
                  borderColor: borderColor,
                  onRemove: () => _removePhoto(photo),
                ),
              AddPhotoTile(borderColor: borderColor, mutedColor: mutedColor, onTap: _addPhoto),
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
