import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/field_group.dart';
import 'vehicle.dart';
import 'vehicle_pending_widgets.dart';

const _accentYellow = AppColors.accent;

/// Report a `VehiculoPendiente`: mechanical failure, tire, or maintenance
/// need. Real `POST /vehiculos/{vehiculoId}/pendientes` — `vehiculoId` comes
/// from `VehicleScreen`'s `VehiculoService.miVehiculo()` lookup. Backend's
/// `VehiculoPendienteRequest` has no urgencia field at all, so that selector
/// was dropped rather than collecting input the server would just discard.
class VehiclePendingScreen extends StatefulWidget {
  final int vehiculoId;

  const VehiclePendingScreen({super.key, required this.vehiculoId});

  @override
  State<VehiclePendingScreen> createState() => _VehiclePendingScreenState();
}

class _VehiclePendingScreenState extends State<VehiclePendingScreen> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  TipoPendiente _tipo = TipoPendiente.fallaMecanica;
  XFile? _photo;
  bool _enviando = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
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
    if (_descriptionController.text.trim().isEmpty) {
      AppSnack.error(context, 'Describe el pendiente antes de enviar');
      return;
    }

    setState(() => _enviando = true);
    try {
      String? evidenciaApertura;
      final photo = _photo;
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final nombreArchivo = 'pendiente_${widget.vehiculoId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final presigned = await OperacionesService.presignedUploadUrl(
          carpeta: 'vehiculo-pendientes',
          nombreArchivo: nombreArchivo,
          contentType: 'image/jpeg',
        );
        await OperacionesService.subirArchivoPresignado(presigned.uploadUrl, bytes, 'image/jpeg');
        evidenciaApertura = presigned.publicUrl;
      }

      await OperacionesService.registrarPendienteVehiculo(
        widget.vehiculoId,
        tipoPendiente: _tipo.backendValue,
        descripcion: _descriptionController.text.trim(),
        evidenciaApertura: evidenciaApertura,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Pendiente reportado');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo reportar el pendiente');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Pendiente'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          SectionLabel(text: 'Tipo de pendiente', textColor: textColor),
          const SizedBox(height: 10),
          FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            expand: true,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tipo in TipoPendiente.values)
                  ChoiceChip(
                    label: Text(tipo.label),
                    avatar: Icon(tipo.icon, size: 16, color: _tipo == tipo ? Colors.black : textColor),
                    selected: _tipo == tipo,
                    onSelected: (_) => setState(() => _tipo = tipo),
                    selectedColor: _accentYellow,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _tipo == tipo ? Colors.black : textColor,
                    ),
                    backgroundColor: fillColor,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionLabel(text: 'Descripción', textColor: textColor),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Describe lo que observaste...',
              hintStyle: TextStyle(color: mutedColor),
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _accentYellow, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SectionLabel(text: 'Evidencia (opcional)', textColor: textColor),
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
                backgroundColor: _accentYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _enviando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : const Text('Enviar reporte', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
