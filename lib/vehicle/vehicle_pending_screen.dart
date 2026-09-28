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

  /// Shown in the header card so the driver sees which unit they're
  /// reporting on — optional, purely for display.
  final String? unidad;
  final String? placas;

  /// Preselected from `VehicleScreen`'s Reportes tab tiles.
  final TipoPendiente? tipoInicial;

  const VehiclePendingScreen({
    super.key,
    required this.vehiculoId,
    this.unidad,
    this.placas,
    this.tipoInicial,
  });

  @override
  State<VehiclePendingScreen> createState() => _VehiclePendingScreenState();
}

class _VehiclePendingScreenState extends State<VehiclePendingScreen> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  late TipoPendiente _tipo = widget.tipoInicial ?? TipoPendiente.fallaMecanica;
  XFile? _photo;
  bool _enviando = false;

  static const _maxDescripcion = 500;

  @override
  void initState() {
    super.initState();
    // Rebuild on typing so the step-2 check and the submit button's enabled
    // state follow the text.
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(source: source, imageQuality: 80);
      if (photo != null) setState(() => _photo = photo);
    } catch (_) {
      if (!mounted) return;
      AppSnack.error(
        context,
        source == ImageSource.camera ? 'No se pudo acceder a la cámara' : 'No se pudo abrir la galería',
      );
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
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final borderColor = AppColors.border(context);
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045);
    final descripcionLista = _descriptionController.text.trim().isNotEmpty;
    final unidadTexto = [widget.unidad, widget.placas].whereType<String>().where((t) => t.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar pendiente'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (unidadTexto.isNotEmpty) ...[
              FieldGroup(
                cardColor: AppColors.card(context),
                borderColor: borderColor,
                expand: true,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: _accentYellow),
                      child: const Icon(Icons.local_shipping_sharp, color: AppColors.onAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Unidad', style: TextStyle(fontSize: 12, color: mutedColor)),
                          Text(
                            unidadTexto,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            const StepHeader(numero: 1, titulo: '¿Qué tipo de problema?', completo: true),
            DropdownButtonFormField<TipoPendiente>(
              initialValue: _tipo,
              isExpanded: true,
              dropdownColor: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              icon: Icon(Icons.keyboard_arrow_down, color: mutedColor),
              style: TextStyle(fontSize: 15, color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: fillColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _accentYellow, width: 1.5),
                ),
              ),
              items: [
                for (final tipo in TipoPendiente.values)
                  DropdownMenuItem(
                    value: tipo,
                    child: Row(
                      children: [
                        Icon(tipo.icon, size: 20, color: _accentYellow),
                        const SizedBox(width: 12),
                        Text(tipo.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (tipo) {
                if (tipo != null) setState(() => _tipo = tipo);
              },
            ),
            const SizedBox(height: 26),
            StepHeader(
              numero: 2,
              titulo: 'Describe el problema',
              subtitulo: 'Escribe con detalle lo que observaste',
              completo: descripcionLista,
            ),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              minLines: 4,
              maxLength: _maxDescripcion,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Ej. Se escucha un golpeteo al frenar desde esta mañana...',
                hintStyle: TextStyle(color: mutedColor),
                counterStyle: TextStyle(color: mutedColor, fontSize: 11.5),
                filled: true,
                fillColor: fillColor,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _accentYellow, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            StepHeader(
              numero: 3,
              titulo: 'Evidencia',
              subtitulo: 'Opcional, pero ayuda al taller a entender el problema',
              completo: _photo != null,
            ),
            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Image.file(File(_photo!.path), height: 200, width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _FotoAccion(
                              icon: Icons.refresh,
                              label: 'Cambiar',
                              onTap: () => _pickPhoto(ImageSource.camera),
                            ),
                            const SizedBox(width: 8),
                            _FotoAccion(icon: Icons.delete_outline, label: 'Quitar', onTap: _removePhoto),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  EvidenciaOptionTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'Tomar foto',
                    onTap: () => _pickPhoto(ImageSource.camera),
                  ),
                  const SizedBox(width: 10),
                  EvidenciaOptionTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Galería',
                    onTap: () => _pickPhoto(ImageSource.gallery),
                  ),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enviando || !descripcionLista ? null : _submit,
              icon: _enviando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _enviando ? 'Enviando...' : 'Enviar reporte de ${_tipo.label.toLowerCase()}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentYellow,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _accentYellow.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FotoAccion extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FotoAccion({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
