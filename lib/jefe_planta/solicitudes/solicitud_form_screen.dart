import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../administracion/administracion_service.dart';
import '../../auth/auth_service.dart';
import '../../operaciones/operaciones_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/field_group.dart';
import '../jefe_planta_service.dart';
import '../jefe_planta_widgets.dart';
import 'solicitudes_widgets.dart';

/// "Nueva solicitud de compra", with the web's fields (finanzas
/// `SolicitudCompraRequest`). Only the concepto is required. Área comes from
/// administración's catalog, and the cotización is a photo uploaded through
/// administración's presigned URL (same `cotizaciones-compra` folder as the
/// web). `plantaId` is the jefe's own planta, so it isn't asked. Pops `true`
/// once created.
class SolicitudFormScreen extends StatefulWidget {
  const SolicitudFormScreen({super.key});

  @override
  State<SolicitudFormScreen> createState() => _SolicitudFormScreenState();
}

class _SolicitudFormScreenState extends State<SolicitudFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _conceptoController = TextEditingController();
  final _motivoController = TextEditingController();
  final _montoController = TextEditingController();
  final _picker = ImagePicker();
  String? _area;
  OllaPlanta? _vehiculo;
  XFile? _cotizacion;
  bool _enviando = false;
  ContextoPlanta? _contexto;
  List<String> _areas = const [];
  List<OllaPlanta> _vehiculos = const [];

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  /// Best-effort: without them the form still works, just without the
  /// área/vehículo pickers.
  Future<void> _cargarCatalogos() async {
    final contexto = await JefePlantaService.contexto();
    if (!mounted) return;
    setState(() => _contexto = contexto);
    await Future.wait([
      () async {
        try {
          final areas = await JefePlantaService.areas();
          if (mounted) setState(() => _areas = areas);
        } catch (_) {}
      }(),
      () async {
        try {
          final vehiculos = await JefePlantaService.ollas(
            plantaId: contexto.miPlantaId,
          );
          if (mounted) setState(() => _vehiculos = vehiculos);
        } catch (_) {}
      }(),
    ]);
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _motivoController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _elegirCotizacion() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceAlt(context),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked != null && mounted) setState(() => _cotizacion = picked);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo abrir la cámara');
    }
  }

  Future<String> _subirCotizacion(XFile file) async {
    final bytes = await file.readAsBytes();
    final contentType = file.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    final presigned = await AdministracionService.presignedUploadUrl(
      carpeta: 'cotizaciones-compra',
      nombreArchivo:
          'cotizacion_${DateTime.now().millisecondsSinceEpoch}.${contentType.split('/').last}',
      contentType: contentType,
    );
    await OperacionesService.subirArchivoPresignado(
      presigned.uploadUrl,
      bytes,
      contentType,
    );
    return presigned.publicUrl;
  }

  String? _opcional(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final cotizacionUrl = _cotizacion == null
          ? null
          : await _subirCotizacion(_cotizacion!);
      final creada = await JefePlantaService.crearSolicitud(
        concepto: _conceptoController.text.trim(),
        area: _area,
        motivo: _opcional(_motivoController),
        montoEstimado: double.tryParse(
          _montoController.text.replaceAll(',', '').trim(),
        ),
        plantaId: _contexto?.miPlantaId,
        vehiculoId: _vehiculo?.id,
        cotizacionAdjuntaUrl: cotizacionUrl,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Solicitud SC-${creada.id} enviada');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo enviar la solicitud');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva solicitud'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            FieldGroup(
              expand: true,
              child: Row(
                children: [
                  const Icon(Icons.factory_outlined, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Planta',
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                        Text(
                          _contexto == null
                              ? 'Cargando…'
                              : _contexto!.miPlantaId == null
                              ? 'Sin planta asignada'
                              : _contexto!.nombrePlanta(_contexto!.miPlantaId),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _conceptoController,
              style: TextStyle(color: textColor),
              textCapitalization: TextCapitalization.sentences,
              decoration: campoJp(
                context,
                'Concepto',
                hint: 'Qué se necesita comprar',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe el concepto'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _montoController,
              style: TextStyle(color: textColor),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: campoJp(
                context,
                'Monto estimado (opcional)',
                prefixIcon: const Icon(Icons.attach_money),
              ),
              validator: (v) {
                final t = (v ?? '').replaceAll(',', '').trim();
                if (t.isEmpty) return null;
                final n = double.tryParse(t);
                return n == null || n < 0 ? 'Monto inválido' : null;
              },
            ),
            if (_areas.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Área (opcional)',
                style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _areas)
                    ChoiceChip(
                      avatar: Icon(
                        iconoArea(a),
                        size: 16,
                        color: _area == a ? AppColors.onAccent : mutedColor,
                      ),
                      label: Text(a),
                      selected: _area == a,
                      showCheckmark: false,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.border(context, alpha: 0.06),
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _area == a ? AppColors.onAccent : textColor,
                      ),
                      // Tapping the selected área again clears it.
                      onSelected: (_) =>
                          setState(() => _area = _area == a ? null : a),
                    ),
                ],
              ),
            ],
            if (_vehiculos.isNotEmpty) ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<OllaPlanta?>(
                initialValue: _vehiculo,
                isExpanded: true,
                decoration: campoJp(
                  context,
                  'Vehículo (si es una refacción)',
                  prefixIcon: const Icon(Icons.local_shipping_outlined),
                ),
                dropdownColor: AppColors.surfaceAlt(context),
                items: [
                  const DropdownMenuItem<OllaPlanta?>(
                    value: null,
                    child: Text('Sin vehículo'),
                  ),
                  for (final v in _vehiculos)
                    DropdownMenuItem<OllaPlanta?>(
                      value: v,
                      child: Text(
                        v.placas == null
                            ? v.numeroUnidad
                            : '${v.numeroUnidad} · ${v.placas}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _vehiculo = v),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _motivoController,
              style: TextStyle(color: textColor),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: campoJp(
                context,
                'Motivo (opcional)',
                hint: 'Por qué se necesita',
              ),
            ),
            const SizedBox(height: 12),
            FieldGroup(
              expand: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _cotizacion == null
                        ? Icons.attach_file
                        : Icons.check_circle,
                    color: _cotizacion == null ? mutedColor : AppColors.success,
                  ),
                  title: Text(
                    _cotizacion == null
                        ? 'Adjuntar cotización (opcional)'
                        : 'Cotización adjunta',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    _cotizacion == null
                        ? 'Foto de la cotización del proveedor'
                        : 'Se subirá al enviar la solicitud',
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
                  trailing: _cotizacion == null
                      ? null
                      : IconButton(
                          tooltip: 'Quitar',
                          icon: Icon(Icons.close, color: mutedColor),
                          onPressed: () => setState(() => _cotizacion = null),
                        ),
                  onTap: _enviando ? null : _elegirCotizacion,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviar,
                style: botonPrimarioJp(),
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text(
                  'Enviar solicitud',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
