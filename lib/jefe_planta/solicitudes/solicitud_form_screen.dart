import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/field_group.dart';
import '../jefe_planta_mock.dart';
import '../jefe_planta_widgets.dart';
import 'solicitudes_widgets.dart';

/// "Nueva solicitud de compra" form — fields mirror finanzas
/// `SolicitudCompraRequest` (area, concepto, motivo, montoEstimado,
/// vehiculoId, cotizacionAdjuntaUrl). `plantaId` is the jefe's own planta,
/// so it isn't asked. Pops `true` once created.
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
  String? _area;
  OllaPlanta? _vehiculo;
  bool _cotizacionAdjunta = false;
  bool _enviando = false;
  List<OllaPlanta> _vehiculos = const [];

  @override
  void initState() {
    super.initState();
    JefePlantaMock.ollas(plantaId: JefePlantaMock.miPlantaId)
        .then((v) {
          if (mounted) setState(() => _vehiculos = v);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _motivoController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final creada = await JefePlantaMock.crearSolicitud(
        area: _area!,
        concepto: _conceptoController.text.trim(),
        motivo: _motivoController.text.trim(),
        montoEstimado: double.tryParse(
          _montoController.text.replaceAll(',', '').trim(),
        ),
        vehiculoId: _area == 'Flota' ? _vehiculo?.id : null,
        conCotizacion: _cotizacionAdjunta,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Solicitud SC-${creada.id} enviada');
      Navigator.of(context).pop(true);
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
    final planta = JefePlantaMock.planta(JefePlantaMock.miPlantaId);

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
            const DatosEjemploBanner(),
            const SizedBox(height: 16),
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
                          planta?.nombre ?? '#${JefePlantaMock.miPlantaId}',
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
            Text(
              'Área',
              style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 10),
            FormField<String>(
              validator: (_) => _area == null ? 'Elige un área' : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in areasSolicitud)
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
                          backgroundColor: AppColors.border(
                            context,
                            alpha: 0.06,
                          ),
                          side: BorderSide.none,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _area == a ? AppColors.onAccent : textColor,
                          ),
                          onSelected: (_) {
                            setState(() => _area = a);
                            field.didChange(a);
                          },
                        ),
                    ],
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        field.errorText!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_area == 'Flota') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<OllaPlanta>(
                initialValue: _vehiculo,
                decoration: campoJp(
                  context,
                  'Vehículo (opcional)',
                  prefixIcon: const Icon(Icons.local_shipping_outlined),
                ),
                dropdownColor: AppColors.surfaceAlt(context),
                items: [
                  for (final v in _vehiculos)
                    DropdownMenuItem(
                      value: v,
                      child: Text(
                        '${v.numeroUnidad} · ${v.placas ?? 'sin placas'}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _vehiculo = v),
              ),
            ],
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
              controller: _motivoController,
              style: TextStyle(color: textColor),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: campoJp(
                context,
                'Motivo',
                hint: 'Por qué se necesita',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe el motivo' : null,
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
            ),
            const SizedBox(height: 12),
            FieldGroup(
              expand: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  value: _cotizacionAdjunta,
                  onChanged: (v) => setState(() => _cotizacionAdjunta = v),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.accent,
                  secondary: Icon(Icons.attach_file, color: mutedColor),
                  title: Text(
                    'Adjuntar cotización',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    _cotizacionAdjunta
                        ? 'Se tomará foto o archivo al conectar el servicio'
                        : 'Foto o PDF del proveedor',
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
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
