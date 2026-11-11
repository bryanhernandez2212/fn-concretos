import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/vehiculo.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/field_group.dart';
import 'vehicle.dart';
import 'vehicle_pending_widgets.dart';

const _accentYellow = AppColors.accent;

String _numero(double n) =>
    n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);

/// Fuel loads of the operator's own vehicle: `GET`/`POST
/// /vehiculos/{id}/combustible`. The backend compares each load against the
/// Samsara tank percentage, so the form only collects what the operator
/// knows: litros (required), odómetro and a ticket photo (both optional).
class VehicleCombustibleScreen extends StatefulWidget {
  final VehiculoResumen vehiculo;

  const VehicleCombustibleScreen({super.key, required this.vehiculo});

  @override
  State<VehicleCombustibleScreen> createState() =>
      _VehicleCombustibleScreenState();
}

class _VehicleCombustibleScreenState extends State<VehicleCombustibleScreen> {
  late Future<List<VehiculoCombustibleResumen>> _future =
      OperacionesService.combustibleVehiculo(widget.vehiculo.id);

  Future<void> _recargar() async {
    final nuevo = OperacionesService.combustibleVehiculo(widget.vehiculo.id);
    setState(() => _future = nuevo);
    try {
      await nuevo;
    } catch (_) {}
  }

  Future<void> _registrar() async {
    final registrado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _RegistrarCombustibleSheet(vehiculoId: widget.vehiculo.id),
    );
    if (registrado == true) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = AppColors.mutedText(context);
    final unidad = [
      widget.vehiculo.numeroUnidad,
      widget.vehiculo.placas,
    ].where((t) => t.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combustible'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: FutureBuilder<List<VehiculoCombustibleResumen>>(
          future: _future,
          builder: (context, snapshot) {
            Widget mensaje(String texto) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32),
              children: [
                Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedColor),
                ),
              ],
            );

            if (snapshot.connectionState != ConnectionState.done) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return mensaje(
                error is AuthException
                    ? error.message
                    : 'No se pudieron cargar las cargas',
              );
            }
            final cargas = snapshot.data!;
            if (cargas.isEmpty) {
              return mensaje('Todavía no hay cargas de combustible registradas');
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (unidad.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      unidad,
                      style: TextStyle(fontSize: 13, color: mutedColor),
                    ),
                  ),
                for (final carga in cargas) ...[
                  _CargaCard(carga: carga),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: AppColors.border(context))),
          ),
          child: ElevatedButton.icon(
            onPressed: _registrar,
            icon: const Icon(Icons.local_gas_station_outlined, size: 20),
            label: const Text(
              'Registrar carga',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentYellow,
              foregroundColor: AppColors.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CargaCard extends StatelessWidget {
  final VehiculoCombustibleResumen carga;

  const _CargaCard({required this.carga});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final detalles = [
      formatoFechaVehiculo(carga.fechaHora, conHora: true),
      if (carga.odometroKm != null) '${_numero(carga.odometroKm!)} km',
      if (carga.samsaraFuelPercent != null)
        'Tanque Samsara: ${_numero(carga.samsaraFuelPercent!)}%',
    ];

    return FieldGroup(
      cardColor: AppColors.card(context),
      borderColor: AppColors.border(context),
      expand: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentYellow.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.local_gas_station_outlined,
              color: _accentYellow,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_numero(carga.litrosCargados)} L',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalles.join(' · '),
                  style: TextStyle(fontSize: 12.5, color: mutedColor),
                ),
              ],
            ),
          ),
          if (carga.evidenciaUrl != null && carga.evidenciaUrl!.isNotEmpty)
            IconButton(
              tooltip: 'Ver ticket',
              icon: Icon(Icons.receipt_long_outlined, color: mutedColor),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(
                    child: Image.network(
                      carga.evidenciaUrl!,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No se pudo cargar la imagen'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RegistrarCombustibleSheet extends StatefulWidget {
  final int vehiculoId;

  const _RegistrarCombustibleSheet({required this.vehiculoId});

  @override
  State<_RegistrarCombustibleSheet> createState() =>
      _RegistrarCombustibleSheetState();
}

class _RegistrarCombustibleSheetState
    extends State<_RegistrarCombustibleSheet> {
  final _litrosController = TextEditingController();
  final _odometroController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _foto;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _litrosController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _litrosController.dispose();
    _odometroController.dispose();
    super.dispose();
  }

  // Accepts a decimal comma too, since the numeric keyboard on some Spanish
  // locales only offers it.
  double? _parse(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _tomarFoto(ImageSource source) async {
    try {
      final foto = await _picker.pickImage(source: source, imageQuality: 80);
      if (foto != null) setState(() => _foto = foto);
    } catch (_) {
      if (!mounted) return;
      AppSnack.error(
        context,
        source == ImageSource.camera
            ? 'No se pudo acceder a la cámara'
            : 'No se pudo abrir la galería',
      );
    }
  }

  Future<void> _enviar() async {
    final litros = _parse(_litrosController.text);
    if (litros == null || litros <= 0) {
      AppSnack.error(context, 'Escribe los litros cargados');
      return;
    }
    final odometroTexto = _odometroController.text.trim();
    final odometro = odometroTexto.isEmpty ? null : _parse(odometroTexto);
    if (odometroTexto.isNotEmpty && (odometro == null || odometro < 0)) {
      AppSnack.error(context, 'El odómetro no es válido');
      return;
    }

    setState(() => _enviando = true);
    try {
      String? evidenciaUrl;
      final foto = _foto;
      if (foto != null) {
        final bytes = await foto.readAsBytes();
        final presigned = await OperacionesService.presignedUploadUrl(
          carpeta: 'vehiculo-combustible',
          nombreArchivo:
              'combustible_${widget.vehiculoId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: 'image/jpeg',
        );
        await OperacionesService.subirArchivoPresignado(
          presigned.uploadUrl,
          bytes,
          'image/jpeg',
        );
        evidenciaUrl = presigned.publicUrl;
      }
      await OperacionesService.registrarCombustible(
        widget.vehiculoId,
        litrosCargados: litros,
        odometroKm: odometro,
        fechaHora: DateTime.now(),
        evidenciaUrl: evidenciaUrl,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Carga registrada');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo registrar la carga');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.045);

    InputDecoration decoracion(String label, String sufijo) => InputDecoration(
      labelText: label,
      suffixText: sufijo,
      labelStyle: TextStyle(color: mutedColor),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _accentYellow, width: 1.5),
      ),
    );

    const numerico = TextInputType.numberWithOptions(decimal: true);
    final puedeEnviar = (_parse(_litrosController.text) ?? 0) > 0 && !_enviando;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar carga',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _litrosController,
              keyboardType: numerico,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: decoracion('Litros cargados', 'L'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _odometroController,
              keyboardType: numerico,
              style: TextStyle(color: textColor),
              decoration: decoracion('Odómetro (opcional)', 'km'),
            ),
            const SizedBox(height: 14),
            if (_foto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Image.file(
                      File(_foto!.path),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IconButton.filledTonal(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _foto = null),
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
                    label: 'Foto del ticket',
                    onTap: () => _tomarFoto(ImageSource.camera),
                  ),
                  const SizedBox(width: 10),
                  EvidenciaOptionTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Galería',
                    onTap: () => _tomarFoto(ImageSource.gallery),
                  ),
                ],
              ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: puedeEnviar ? _enviar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentYellow,
                foregroundColor: AppColors.onAccent,
                disabledBackgroundColor: _accentYellow.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _enviando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
