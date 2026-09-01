import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/field_group.dart';
import 'asesor_comercial_service.dart';
import 'visita.dart';

/// Registers a geolocated check-in for [visita], with an optional camera
/// photo. `comercial-service` has no presigned-upload endpoint of its own
/// (only `evidenciaUrl`/`fotoEvidenciaUrl` string fields expecting an
/// already-public URL), so this deliberately reuses
/// `OperacionesService.presignedUploadUrl`/`subirArchivoPresignado` — a
/// cross-service call purely to get a public URL from the same storage
/// bucket every other evidencia upload in this app already uses.
class VisitaCheckinScreen extends StatefulWidget {
  final Visita visita;

  const VisitaCheckinScreen({super.key, required this.visita});

  @override
  State<VisitaCheckinScreen> createState() => _VisitaCheckinScreenState();
}

class _VisitaCheckinScreenState extends State<VisitaCheckinScreen> {
  final _picker = ImagePicker();
  final _contactoNombreController = TextEditingController();
  final _contactoTelefonoController = TextEditingController();
  XFile? _photo;
  Position? _posicion;
  bool _obteniendoUbicacion = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  @override
  void dispose() {
    _contactoNombreController.dispose();
    _contactoTelefonoController.dispose();
    super.dispose();
  }

  Future<void> _obtenerUbicacion() async {
    setState(() => _obteniendoUbicacion = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      if (!granted) {
        if (mounted) AppSnack.error(context, 'Se necesita el permiso de ubicación para el check-in');
        return;
      }
      final posicion = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _posicion = posicion);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo obtener la ubicación');
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (photo != null) setState(() => _photo = photo);
    } catch (_) {
      if (!mounted) return;
      AppSnack.error(context, 'No se pudo acceder a la cámara');
    }
  }

  void _removePhoto() => setState(() => _photo = null);

  Future<void> _submit() async {
    final posicion = _posicion;
    if (posicion == null) {
      AppSnack.error(context, 'Espera a que se obtenga tu ubicación');
      return;
    }

    setState(() => _enviando = true);
    try {
      String? fotoEvidenciaUrl;
      final photo = _photo;
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final nombreArchivo = 'checkin_${widget.visita.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final presigned = await OperacionesService.presignedUploadUrl(
          carpeta: 'visita-checkins',
          nombreArchivo: nombreArchivo,
          contentType: 'image/jpeg',
        );
        await OperacionesService.subirArchivoPresignado(presigned.uploadUrl, bytes, 'image/jpeg');
        fotoEvidenciaUrl = presigned.publicUrl;
      }

      final actualizada = await AsesorComercialService.checkin(
        widget.visita.id,
        latitud: posicion.latitude,
        longitud: posicion.longitude,
        fotoEvidenciaUrl: fotoEvidenciaUrl,
        contactoNombre: _contactoNombreController.text.trim().isEmpty ? null : _contactoNombreController.text.trim(),
        contactoTelefono: _contactoTelefonoController.text.trim().isEmpty ? null : _contactoTelefonoController.text.trim(),
        metodoCheckin: 'app_movil',
      );
      if (!mounted) return;
      AppSnack.success(context, 'Check-in registrado');
      Navigator.of(context).pop(actualizada);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo registrar el check-in');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);
    final fillColor = AppColors.border(context, alpha: 0.06);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar check-in'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            expand: true,
            child: Row(
              children: [
                Icon(
                  _obteniendoUbicacion
                      ? Icons.hourglass_empty
                      : (_posicion == null ? Icons.location_off_outlined : Icons.location_on_outlined),
                  color: _posicion == null ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _obteniendoUbicacion
                        ? 'Obteniendo tu ubicación...'
                        : (_posicion == null
                              ? 'No se pudo obtener tu ubicación'
                              : 'Ubicación lista: ${_posicion!.latitude.toStringAsFixed(5)}, ${_posicion!.longitude.toStringAsFixed(5)}'),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ),
                if (!_obteniendoUbicacion && _posicion == null)
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _obtenerUbicacion),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Contacto en obra (opcional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 10),
          TextField(
            controller: _contactoNombreController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Nombre de quien te atendió',
              hintStyle: TextStyle(color: mutedColor),
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactoTelefonoController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Teléfono (opcional)',
              hintStyle: TextStyle(color: mutedColor),
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Evidencia fotográfica (opcional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 10),
          if (_photo != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(border: Border.all(color: borderColor)),
                    child: Image.file(File(_photo!.path), fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: _removePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Tomar foto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _enviando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : const Text('Registrar check-in', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
