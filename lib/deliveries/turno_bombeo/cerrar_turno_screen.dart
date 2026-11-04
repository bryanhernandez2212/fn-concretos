import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../operaciones/operaciones_service.dart';
import '../../operaciones/orden_trabajo_bombeo.dart';
import '../../operaciones/remision_tracking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/field_group.dart';
import 'turno_bombeo_widgets.dart';

/// Closes the open turno: horómetro fin, precio por m³, recibo and the
/// encargado de obra's name (free text, not a firma). `volumenPorCobrar`
/// is computed by the backend. Pops `true` once closed.
class CerrarTurnoScreen extends StatefulWidget {
  final OrdenTrabajoBombeo turno;
  final List<RemisionResumen> remisiones;

  const CerrarTurnoScreen({
    super.key,
    required this.turno,
    required this.remisiones,
  });

  @override
  State<CerrarTurnoScreen> createState() => _CerrarTurnoScreenState();
}

class _CerrarTurnoScreenState extends State<CerrarTurnoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _horometroFin = TextEditingController();
  final _precio = TextEditingController();
  final _importe = TextEditingController();
  final _folioRecibo = TextEditingController();
  final _encargado = TextEditingController();
  final _observaciones = TextEditingController();
  bool _tieneRecibo = false;
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [
      _horometroFin,
      _precio,
      _importe,
      _folioRecibo,
      _encargado,
      _observaciones,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validarHorometroFin(String? v) {
    final base = validarNumeroOpcional(v);
    if (base != null) return base;
    final fin = double.tryParse((v ?? '').replaceAll(',', '.').trim());
    final inicio = widget.turno.horometroInicio;
    if (fin != null && inicio != null && fin < inicio) {
      return 'Debe ser mayor o igual al de inicio ($inicio)';
    }
    return null;
  }

  Future<bool> _confirmar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt(context),
        title: const Text('¿Cerrar turno?'),
        content: const Text(
          'Una vez cerrado ya no podrás modificarlo desde la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              elevation: 0,
            ),
            child: const Text(
              'Cerrar turno',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return confirmado == true;
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmar() || !mounted) return;
    setState(() => _enviando = true);
    try {
      final cerrado = await OperacionesService.cerrarTurnoBombeo(
        widget.turno.id,
        horometroFin: leerNumero(_horometroFin),
        precioPorM3: leerNumero(_precio),
        tieneRecibo: _tieneRecibo,
        importeRecibo: _tieneRecibo ? leerNumero(_importe) : null,
        folioRecibo: _tieneRecibo ? leerTexto(_folioRecibo) : null,
        encargadoObraNombre: leerTexto(_encargado),
        observaciones: leerTexto(_observaciones),
      );
      if (!mounted) return;
      final volumen = cerrado.volumenPorCobrar;
      AppSnack.success(
        context,
        volumen == null
            ? 'Turno cerrado'
            : 'Turno cerrado · $volumen m³ por cobrar',
      );
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo cerrar el turno');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _campo(
    TextEditingController c,
    String label, {
    String? suffix,
    Widget? prefixIcon,
    bool numerico = false,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        style: TextStyle(color: AppColors.text(context)),
        keyboardType: numerico
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        textCapitalization: numerico
            ? TextCapitalization.none
            : TextCapitalization.sentences,
        maxLines: maxLines,
        decoration: campoTurno(
          context,
          label,
          suffix: suffix,
          prefixIcon: prefixIcon,
        ),
        validator: validator ?? (numerico ? validarNumeroOpcional : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final turno = widget.turno;
    final sinMetros = widget.remisiones
        .where((r) => r.metrosBombeados == null)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerrar turno'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    turno.folio.isEmpty ? 'Turno #${turno.id}' : turno.folio,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (turno.horometroInicio != null)
                        'Horómetro inicio ${turno.horometroInicio}',
                      '${widget.remisiones.length} remisiones',
                    ].join(' · '),
                    style: TextStyle(fontSize: 13, color: mutedColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El volumen por cobrar lo calcula el sistema al cerrar, con los m³ bombeados de cada remisión.',
                    style: TextStyle(fontSize: 12.5, color: mutedColor),
                  ),
                  if (sinMetros > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sinMetros == 1
                                ? '1 remisión no tiene m³ bombeados capturados.'
                                : '$sinMetros remisiones no tienen m³ bombeados capturados.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _campo(
              _horometroFin,
              'Horómetro final',
              numerico: true,
              validator: _validarHorometroFin,
            ),
            _campo(
              _precio,
              'Precio por m³',
              numerico: true,
              prefixIcon: const Icon(Icons.attach_money),
            ),
            _campo(_encargado, 'Encargado de obra'),
            const SizedBox(height: 4),
            FieldGroup(
              expand: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _tieneRecibo,
                activeThumbColor: AppColors.accent,
                onChanged: (v) => setState(() => _tieneRecibo = v),
                title: Text(
                  'Se entregó recibo',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_tieneRecibo) ...[
              _campo(_folioRecibo, 'Folio del recibo'),
              _campo(
                _importe,
                'Importe del recibo',
                numerico: true,
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ],
            _campo(_observaciones, 'Observaciones (opcional)', maxLines: 3),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  disabledBackgroundColor: AppColors.accent.withValues(
                    alpha: 0.3,
                  ),
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
                        'Cerrar turno',
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
