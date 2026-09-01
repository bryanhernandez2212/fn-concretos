import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/field_group.dart';
import 'asesor_comercial_service.dart';

/// Creates a `Cotizacion` for a cliente/obra a Visita already resolved —
/// cotizaciones originate from visits in this app, so `clienteId`/`obraId`
/// are prefilled read-only rather than picked freehand here.
class CotizacionFormScreen extends StatefulWidget {
  final int clienteId;
  final String clienteNombre;
  final int? obraId;
  final String? obraNombre;

  const CotizacionFormScreen({
    super.key,
    required this.clienteId,
    required this.clienteNombre,
    this.obraId,
    this.obraNombre,
  });

  @override
  State<CotizacionFormScreen> createState() => _CotizacionFormScreenState();
}

class _CotizacionFormScreenState extends State<CotizacionFormScreen> {
  final _volumenController = TextEditingController();
  final _precioController = TextEditingController();
  final _tipoServicioController = TextEditingController();
  final _formaPagoController = TextEditingController();
  final _descuentoController = TextEditingController();
  DateTime? _fechaSuministro;
  bool _requiereFactura = false;
  bool _enviando = false;

  bool get _puedeAplicarDescuento => AuthService.permisos.contains(permisoAplicarDescuentoEspecial);

  @override
  void dispose() {
    _volumenController.dispose();
    _precioController.dispose();
    _tipoServicioController.dispose();
    _formaPagoController.dispose();
    _descuentoController.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: hoy,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      locale: const Locale('es'),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(colorScheme: base.colorScheme.copyWith(primary: AppColors.accent, onPrimary: Colors.black)),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fechaSuministro = picked);
  }

  Future<void> _submit() async {
    final volumen = double.tryParse(_volumenController.text.trim());
    final precio = double.tryParse(_precioController.text.trim());
    if (volumen == null || precio == null) {
      AppSnack.error(context, 'Ingresa un volumen y precio unitario válidos');
      return;
    }

    setState(() => _enviando = true);
    try {
      await AsesorComercialService.crearCotizacion(
        clienteId: widget.clienteId,
        obraId: widget.obraId,
        volumenM3: volumen,
        precioUnitario: precio,
        tipoServicio: _tipoServicioController.text.trim().isEmpty ? null : _tipoServicioController.text.trim(),
        formaPago: _formaPagoController.text.trim().isEmpty ? null : _formaPagoController.text.trim(),
        requiereFactura: _requiereFactura,
        fechaSuministroEstimada: _fechaSuministro,
        porcentajeDescuento: _puedeAplicarDescuento && _descuentoController.text.trim().isNotEmpty
            ? double.tryParse(_descuentoController.text.trim())
            : null,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Cotización creada');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo crear la cotización');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  InputDecoration _decoration(String hint, Color mutedColor, Color fillColor) {
    return InputDecoration(
      hintText: hint,
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
    );
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
        title: const Text('Nueva cotización'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.clienteNombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                if (widget.obraNombre != null) ...[
                  const SizedBox(height: 4),
                  Text(widget.obraNombre!, style: TextStyle(fontSize: 13, color: mutedColor)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _volumenController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor),
            decoration: _decoration('Volumen (m³)', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _precioController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor),
            decoration: _decoration('Precio unitario', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tipoServicioController,
            style: TextStyle(color: textColor),
            decoration: _decoration('Tipo de servicio', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _formaPagoController,
            style: TextStyle(color: textColor),
            decoration: _decoration('Forma de pago', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickFecha,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: mutedColor),
                  const SizedBox(width: 12),
                  Text(
                    _fechaSuministro == null ? 'Fecha de suministro estimada' : DateFormat('d/MM/y').format(_fechaSuministro!),
                    style: TextStyle(color: _fechaSuministro == null ? mutedColor : textColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _requiereFactura,
            onChanged: (value) => setState(() => _requiereFactura = value),
            title: Text('Requiere factura', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.accent,
            contentPadding: EdgeInsets.zero,
          ),
          if (_puedeAplicarDescuento) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _descuentoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: textColor),
              decoration: _decoration('% de descuento especial', mutedColor, fillColor),
            ),
          ],
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
                  : const Text('Crear cotización', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
