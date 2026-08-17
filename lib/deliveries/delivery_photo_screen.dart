import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import 'delivery_photo_widgets.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Photo/evidence capture for a delivery, backed by `RemisionArchivo`.
/// "Tomar foto" / "Elegir de galería" are real — tapping either triggers
/// the OS's own camera/photo-library permission prompt automatically (via
/// `image_picker`), no manual in-app toggle asks first. "Guardar evidencia"
/// is real too: each photo goes through the same presigned-upload round
/// trip as `SignatureScreen` (`POST /evidencias/presigned-url` + direct
/// `PUT` to storage), then `POST /remisiones/{id}/archivos` with the
/// resulting `publicUrl`. Requires [permisoOperarRemisiones].
class DeliveryPhotoScreen extends StatefulWidget {
  final int remisionId;
  final String remisionFolio;

  const DeliveryPhotoScreen({super.key, required this.remisionId, required this.remisionFolio});

  @override
  State<DeliveryPhotoScreen> createState() => _DeliveryPhotoScreenState();
}

class _DeliveryPhotoScreenState extends State<DeliveryPhotoScreen> {
  final List<XFile> _photos = [];
  final _picker = ImagePicker();
  bool _guardando = false;

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

  String _contentTypeOf(XFile photo) {
    final path = photo.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _save() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una foto')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      for (final photo in _photos) {
        final bytes = await photo.readAsBytes();
        final contentType = _contentTypeOf(photo);
        final extension = contentType.split('/').last;
        final nombreArchivo = 'evidencia_${widget.remisionId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final presigned = await OperacionesService.presignedUploadUrl(
          carpeta: 'remision-evidencias',
          nombreArchivo: nombreArchivo,
          contentType: contentType,
        );
        await OperacionesService.subirArchivoPresignado(presigned.uploadUrl, bytes, contentType);
        await OperacionesService.agregarArchivo(
          widget.remisionId,
          tipoArchivo: 'foto_evidencia',
          archivoUrl: presigned.publicUrl,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidencia guardada')),
      );
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
              onPressed: _guardando ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentYellow,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _accentYellow.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _guardando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Text('Guardar evidencia', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
