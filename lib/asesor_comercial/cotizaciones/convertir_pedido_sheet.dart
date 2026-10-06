import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../auth/auth_service.dart';
import '../../comercial/comercial_service.dart';
import '../../comercial/pedido.dart';
import '../../finanzas/finanzas_service.dart';
import '../../theme/app_colors.dart';
import '../asesor_comercial_service.dart';
import '../pedidos/pedidos_widgets.dart';
import 'cotizacion.dart';

/// What the sheet pops with: the created pedido, plus [avisoAnticipo] when
/// the pedido was created but registering its anticipo failed (same
/// fallback as the web: the pedido stands, the payment goes in by hand).
class ConversionPedidoResultado {
  final Pedido pedido;
  final String? avisoAnticipo;

  const ConversionPedidoResultado(this.pedido, this.avisoAnticipo);
}

/// "Convertir cotización en pedido", mirroring the web's modal: fecha
/// programada de entrega, condición de pago (Liquidado / Anticipo / Crédito
/// / Liquidar en obra), días de crédito (only for Crédito) and, for
/// Anticipo, an optional payment registered right away (`POST /pagos`).
Future<ConversionPedidoResultado?> mostrarConvertirPedidoSheet(BuildContext context, Cotizacion cotizacion) {
  return showModalBottomSheet<ConversionPedidoResultado>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceAlt(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => ConvertirPedidoSheet(cotizacion: cotizacion),
  );
}

class ConvertirPedidoSheet extends StatefulWidget {
  final Cotizacion cotizacion;

  const ConvertirPedidoSheet({super.key, required this.cotizacion});

  @override
  State<ConvertirPedidoSheet> createState() => _ConvertirPedidoSheetState();
}

class _ConvertirPedidoSheetState extends State<ConvertirPedidoSheet> {
  late DateTime _fecha;
  String? _condicionPago;
  final _diasController = TextEditingController();
  final _montoAnticipoController = TextEditingController();
  String? _metodoPagoAnticipo;
  String? _cuentaDestinoAnticipo;
  int? _diasCreditoCliente;
  bool _enviando = false;
  String? _error;

  static const _iconos = {
    'liquidado': Icons.check_circle_outline,
    'anticipo': Icons.savings_outlined,
    'credito': Icons.credit_card_outlined,
    'liquidar_obra': Icons.construction_outlined,
  };

  @override
  void initState() {
    super.initState();
    final sugerida = DateTime.tryParse(widget.cotizacion.fechaSuministroEstimada ?? '');
    final manana = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    _fecha = sugerida != null && !sugerida.isBefore(manana) ? sugerida : manana;
    _cargarCreditoCliente();
  }

  @override
  void dispose() {
    _diasController.dispose();
    _montoAnticipoController.dispose();
    super.dispose();
  }

  /// Best-effort: prefills días de crédito with the cliente's own terms.
  Future<void> _cargarCreditoCliente() async {
    try {
      final cliente = await ComercialService.obtenerCliente(widget.cotizacion.clienteId);
      if (!mounted || cliente.diasCredito <= 0) return;
      setState(() => _diasCreditoCliente = cliente.diasCredito);
    } catch (_) {}
  }

  /// Like the web, switching condición clears the fields that only apply to
  /// the previous one.
  void _elegirCondicion(String condicion) {
    setState(() {
      _condicionPago = condicion;
      _error = null;
      if (condicion != 'credito') {
        _diasController.clear();
      } else if (_diasCreditoCliente != null) {
        _diasController.text = '$_diasCreditoCliente';
      }
      if (condicion != 'anticipo') {
        _montoAnticipoController.clear();
        _metodoPagoAnticipo = null;
        _cuentaDestinoAnticipo = null;
      }
    });
  }

  Future<void> _pickFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      locale: const Locale('es'),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(primary: AppColors.accent, onPrimary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _convertir() async {
    final condicion = _condicionPago;
    if (condicion == null) {
      setState(() => _error = 'Elige la condición de pago');
      return;
    }
    final montoAnticipo = condicion == 'anticipo' ? double.tryParse(_montoAnticipoController.text.trim()) : null;
    if (montoAnticipo != null && _metodoPagoAnticipo == null) {
      setState(() => _error = 'Selecciona el método de pago del anticipo');
      return;
    }
    final diasTexto = _diasController.text.trim();

    setState(() {
      _enviando = true;
      _error = null;
    });
    final Pedido pedido;
    try {
      pedido = await AsesorComercialService.convertirAPedido(
        widget.cotizacion.id,
        fechaProgramada: _fecha,
        condicionPago: condicion,
        diasCredito: diasTexto.isEmpty ? null : int.tryParse(diasTexto),
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _enviando = false;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo convertir la cotización en pedido';
          _enviando = false;
        });
      }
      return;
    }

    String? avisoAnticipo;
    if (montoAnticipo != null) {
      try {
        await FinanzasService.registrarAnticipo(
          clienteId: widget.cotizacion.clienteId,
          pedidoId: pedido.id,
          cotizacionId: widget.cotizacion.id,
          monto: montoAnticipo,
          metodoPago: _metodoPagoAnticipo!,
          cuentaDestino: _cuentaDestinoAnticipo,
          requiereFactura: widget.cotizacion.requiereFactura,
          vendedorId: widget.cotizacion.asesorId,
        );
      } catch (e) {
        final detalle = e is AuthException ? e.message : 'error desconocido';
        avisoAnticipo =
            'El pedido se creó correctamente, pero no se pudo registrar el anticipo ($detalle). Regístralo manualmente en Pagos.';
      }
    }
    if (mounted) Navigator.of(context).pop(ConversionPedidoResultado(pedido, avisoAnticipo));
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final borderColor = AppColors.border(context, alpha: 0.10);
    final fillColor = AppColors.border(context, alpha: 0.06);
    final c = widget.cotizacion;
    final esCredito = _condicionPago == 'credito';
    final esAnticipo = _condicionPago == 'anticipo';
    final hayMontoAnticipo = _montoAnticipoController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.18)),
                  child: const Icon(Icons.assignment_turned_in_outlined, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Convertir en pedido',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
                      ),
                      Text('Cotización ${c.folio}', style: TextStyle(fontSize: 13, color: mutedColor)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: mutedColor),
                  onPressed: _enviando ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ResumenCotizacion(cotizacion: c, textColor: textColor, mutedColor: mutedColor, fillColor: fillColor),
            const SizedBox(height: 22),
            _Etiqueta('Fecha programada de entrega', mutedColor),
            const SizedBox(height: 8),
            Material(
              color: fillColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _enviando ? null : _pickFecha,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 20, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _capitalizada(DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(_fecha)),
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: textColor),
                        ),
                      ),
                      Text('Cambiar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: mutedColor)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            _Etiqueta('Condición de pago', mutedColor),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                for (final entry in condicionPagoOpciones.entries)
                  _OpcionPago(
                    icon: _iconos[entry.key] ?? Icons.payments_outlined,
                    titulo: entry.value,
                    seleccionada: _condicionPago == entry.key,
                    onTap: _enviando ? null : () => _elegirCondicion(entry.key),
                    textColor: textColor,
                    mutedColor: mutedColor,
                    fillColor: fillColor,
                  ),
              ],
            ),
            const SizedBox(height: 22),
            _Etiqueta(esCredito ? 'Días de crédito' : 'Días de crédito (solo aplica a Crédito)', mutedColor),
            const SizedBox(height: 8),
            _Campo(
              controller: _diasController,
              enabled: esCredito && !_enviando,
              hint: esCredito ? 'Ej. 30' : 'No aplica',
              icon: Icons.schedule_outlined,
              suffix: esCredito ? 'días' : null,
              soloEnteros: true,
              onChanged: () => setState(() => _error = null),
              textColor: textColor,
              mutedColor: mutedColor,
              fillColor: fillColor,
            ),
            if (esCredito && _diasCreditoCliente != null) ...[
              const SizedBox(height: 6),
              Text(
                'El cliente tiene $_diasCreditoCliente días de crédito autorizados.',
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            ],
            if (esAnticipo) ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anticipo (opcional)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Si el cliente ya entregó el anticipo, regístralo aquí para no tener que buscar el pedido después en Pagos.',
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                    const SizedBox(height: 14),
                    _Etiqueta('Monto del anticipo', mutedColor),
                    const SizedBox(height: 8),
                    _Campo(
                      controller: _montoAnticipoController,
                      enabled: !_enviando,
                      hint: '0.00',
                      icon: Icons.attach_money,
                      onChanged: () => setState(() => _error = null),
                      textColor: textColor,
                      mutedColor: mutedColor,
                      fillColor: fillColor,
                    ),
                    const SizedBox(height: 14),
                    _Etiqueta('Método de pago', mutedColor),
                    const SizedBox(height: 8),
                    _Selector(
                      value: _metodoPagoAnticipo,
                      opciones: metodoPagoOpciones,
                      hint: 'Seleccionar…',
                      enabled: hayMontoAnticipo && !_enviando,
                      onChanged: (v) => setState(() {
                        _metodoPagoAnticipo = v;
                        _error = null;
                      }),
                      textColor: textColor,
                      mutedColor: mutedColor,
                      fillColor: fillColor,
                    ),
                    const SizedBox(height: 14),
                    _Etiqueta('Cuenta destino (opcional)', mutedColor),
                    const SizedBox(height: 8),
                    _Selector(
                      value: _cuentaDestinoAnticipo,
                      opciones: cuentaDestinoOpciones,
                      hint: 'Sin especificar',
                      enabled: hayMontoAnticipo && !_enviando,
                      onChanged: (v) => setState(() => _cuentaDestinoAnticipo = v),
                      textColor: textColor,
                      mutedColor: mutedColor,
                      fillColor: fillColor,
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _convertir,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_enviando ? 'Convirtiendo…' : 'Crear pedido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
                  disabledForegroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalizada(String texto) => texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;

  const _Etiqueta(this.texto, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color));
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final IconData icon;
  final String? suffix;
  final bool soloEnteros;
  final VoidCallback onChanged;
  final Color textColor;
  final Color mutedColor;
  final Color fillColor;

  const _Campo({
    required this.controller,
    required this.enabled,
    required this.hint,
    required this.icon,
    this.suffix,
    this.soloEnteros = false,
    required this.onChanged,
    required this.textColor,
    required this.mutedColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: soloEnteros ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        soloEnteros ? FilteringTextInputFormatter.digitsOnly : FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      onChanged: (_) => onChanged(),
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: mutedColor),
        suffixText: suffix,
        suffixStyle: TextStyle(color: mutedColor),
        prefixIcon: Icon(icon, color: enabled ? AppColors.accent : mutedColor),
        filled: true,
        fillColor: enabled ? fillColor : fillColor.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _Selector extends StatelessWidget {
  final String? value;
  final Map<String, String> opciones;
  final String hint;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final Color textColor;
  final Color mutedColor;
  final Color fillColor;

  const _Selector({
    required this.value,
    required this.opciones,
    required this.hint,
    required this.enabled,
    required this.onChanged,
    required this.textColor,
    required this.mutedColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      key: ValueKey(value),
      isExpanded: true,
      dropdownColor: AppColors.surfaceAlt(context),
      style: TextStyle(color: textColor, fontSize: 14.5, fontWeight: FontWeight.w600),
      iconEnabledColor: mutedColor,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: mutedColor),
        filled: true,
        fillColor: enabled ? fillColor : fillColor.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      items: [
        for (final entry in opciones.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// Cliente, obra, volumen and total of the cotización being converted.
class _ResumenCotizacion extends StatelessWidget {
  final Cotizacion cotizacion;
  final Color textColor;
  final Color mutedColor;
  final Color fillColor;

  const _ResumenCotizacion({
    required this.cotizacion,
    required this.textColor,
    required this.mutedColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = cotizacion;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.clienteNombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
          if (c.obraNombre != null) ...[
            const SizedBox(height: 2),
            Text(c.obraNombre!, style: TextStyle(fontSize: 13, color: mutedColor)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Dato(etiqueta: 'Volumen', valor: '${c.volumenM3} m³', textColor: textColor, mutedColor: mutedColor),
              ),
              Expanded(
                child: _Dato(
                  etiqueta: 'Total',
                  valor: '\$${NumberFormat('#,##0.00', 'es_MX').format(c.montoTotal)}',
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color textColor;
  final Color mutedColor;

  const _Dato({required this.etiqueta, required this.valor, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: TextStyle(fontSize: 12, color: mutedColor)),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
      ],
    );
  }
}

class _OpcionPago extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final bool seleccionada;
  final VoidCallback? onTap;
  final Color textColor;
  final Color mutedColor;
  final Color fillColor;

  const _OpcionPago({
    required this.icon,
    required this.titulo,
    required this.seleccionada,
    required this.onTap,
    required this.textColor,
    required this.mutedColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionada ? AppColors.accent.withValues(alpha: 0.14) : fillColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: seleccionada ? AppColors.accent : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: seleccionada ? AppColors.accent : mutedColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
