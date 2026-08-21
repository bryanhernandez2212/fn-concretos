import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import 'delivery_photo_widgets.dart';

const _accentYellow = AppColors.accent;

/// Photo/evidence capture for a delivery, backed by `RemisionArchivo`.
/// "Tomar foto" / "Elegir de galería" are real — tapping either triggers
/// the OS's own camera/photo-library permission prompt automatically (via
/// `image_picker`), no manual in-app toggle asks first. "Guardar evidencia"
/// is real too: each photo goes through the same presigned-upload round
/// trip as `SignatureScreen` (`POST /evidencias/presigned-url` + direct
/// `PUT` to storage), then `POST /remisiones/{id}/archivos` with the
/// resulting `publicUrl`. Requires [permisoOperarRemisiones].
///
/// Only reachable from `DeliveryDetailScreen` while no evidencia photo
/// exists yet for the remisión — once one does, that row opens a read-only
/// viewer instead (same idea as firma: the backend has no concept of
/// "replacing" an already-saved photo, so this screen never needs to show
/// existing ones alongside new picks).
class DeliveryPhotoScreen extends StatefulWidget {
  final int remisionId;
  final String remisionFolio;

  const DeliveryPhotoScreen({
    super.key,
    required this.remisionId,
    required this.remisionFolio,
  });

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
      AppSnack.error(context, 'No se pudo acceder a la cámara/galería');
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
      AppSnack.error(context, 'Agrega al menos una foto');
      return;
    }

    setState(() => _guardando = true);
    // Snapshot the pending photos and only remove each one from _photos
    // once it's actually saved — if a later photo in the batch fails (e.g.
    // a flaky connection in the field), the ones already uploaded/attached
    // stay removed, so retrying "Guardar evidencia" doesn't re-upload (and
    // duplicate) them, only the ones still pending.
    final pendientes = List<XFile>.from(_photos);
    String? errorMessage;
    for (final photo in pendientes) {
      try {
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
        if (mounted) setState(() => _photos.remove(photo));
      } on AuthException catch (e) {
        errorMessage = e.message;
        break;
      }
    }

    if (!mounted) return;
    setState(() => _guardando = false);
    if (errorMessage != null) {
      AppSnack.error(context, errorMessage);
      return;
    }
    AppSnack.success(context, 'Evidencia guardada');
    Navigator.of(context).pop(true);
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
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
