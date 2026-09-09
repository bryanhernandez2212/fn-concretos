import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../catalogo/catalogo_service.dart';
import '../catalogo/producto.dart';
import '../direccion/comercial_service.dart';
import '../direccion/pedido.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/field_group.dart';
import 'asesor_comercial_service.dart';
import 'asesor_comercial_widgets.dart';
import 'cotizacion.dart';
import 'cotizacion_form_screen.dart';

/// Detail + status actions for a Cotizacion. On success, "Convertir a
/// pedido" shows the resulting folio and pops back to the list rather than
/// deep-linking into `direccion/PedidoDetailScreen` — that screen exposes
/// Dirección-only aprobar/rechazar actions that shouldn't be shown to an
/// Asesor Comercial.
class CotizacionDetailScreen extends StatefulWidget {
  final Cotizacion cotizacion;

  const CotizacionDetailScreen({super.key, required this.cotizacion});

  @override
  State<CotizacionDetailScreen> createState() => _CotizacionDetailScreenState();
}

class _CotizacionDetailScreenState extends State<CotizacionDetailScreen> {
  late Cotizacion _cotizacion;
  bool _procesando = false;
  List<Producto> _productos = const [];
  List<ClienteContacto> _contactos = const [];

  @override
  void initState() {
    super.initState();
    _cotizacion = widget.cotizacion;
    _cargarProductos();
    _cargarContactos();
  }

  /// Best-effort — resolves `contactoId` to a nombre for display; a failed
  /// lookup just shows the raw id instead of a name.
  Future<void> _cargarContactos() async {
    try {
      final contactos = await ComercialService.contactosCliente(_cotizacion.clienteId);
      if (mounted) setState(() => _contactos = contactos);
    } catch (_) {
      // Falls back to showing the raw contactoId below.
    }
  }

  String? _nombreContacto(int? contactoId) {
    if (contactoId == null) return null;
    for (final c in _contactos) {
      if (c.id == contactoId) return c.nombre;
    }
    return null;
  }

  /// Best-effort — resolves each partida's `productoId` to a nombre for
  /// display; a failed catalog lookup just falls back to showing the
  /// partida's tipoLinea/descripción instead, not a broken screen.
  Future<void> _cargarProductos() async {
    try {
      final productos = await CatalogoService.productos();
      if (mounted) setState(() => _productos = productos);
    } catch (_) {
      // Falls back to descripción/tipoLinea in _partidaRow.
    }
  }

  String? _nombreProducto(int? productoId) {
    if (productoId == null) return null;
    for (final p in _productos) {
      if (p.id == productoId) return p.nombre;
    }
    return null;
  }

  Future<void> _actualizarEstatus(String estatus) async {
    setState(() => _procesando = true);
    try {
      await AsesorComercialService.actualizarEstatusCotizacion(_cotizacion.id, estatus: estatus);
      final actualizada = await AsesorComercialService.obtenerCotizacion(_cotizacion.id);
      if (!mounted) return;
      setState(() => _cotizacion = actualizada);
      AppSnack.success(context, 'Cotización actualizada');
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo actualizar la cotización');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _confirmarCancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cotización'),
        content: const Text('¿Seguro que quieres cancelar esta cotización?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmar == true) _actualizarEstatus('cancelada');
  }

  Future<void> _editar() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CotizacionFormScreen(
          clienteId: _cotizacion.clienteId,
          clienteNombre: _cotizacion.clienteNombre,
          obraId: _cotizacion.obraId,
          obraNombre: _cotizacion.obraNombre,
          cotizacion: _cotizacion,
        ),
      ),
    );
    if (guardado != true || !mounted) return;
    try {
      final actualizada = await AsesorComercialService.obtenerCotizacion(_cotizacion.id);
      if (mounted) setState(() => _cotizacion = actualizada);
    } catch (_) {
      // Best-effort refresh — the edit itself already succeeded.
    }
  }

  Future<void> _duplicar() async {
    setState(() => _procesando = true);
    try {
      await AsesorComercialService.duplicarCotizacion(_cotizacion.id);
      if (!mounted) return;
      AppSnack.success(context, 'Cotización duplicada para renegociar');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo duplicar la cotización');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _convertirAPedido() async {
    final resultado = await showDialog<_ConversionInput>(
      context: context,
      builder: (context) => _ConvertirPedidoDialog(fechaSugerida: DateTime.now().add(const Duration(days: 1))),
    );
    if (resultado == null) return;

    setState(() => _procesando = true);
    try {
      final pedido = await AsesorComercialService.convertirAPedido(
        _cotizacion.id,
        fechaProgramada: resultado.fechaProgramada,
        condicionPago: resultado.condicionPago,
        diasCredito: resultado.diasCredito,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Pedido ${pedido.folio} generado');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo convertir la cotización a pedido');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);
    final c = _cotizacion;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.folio),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop(true)),
        actions: [
          if (c.estatus != 'convertida')
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar cotización', onPressed: _procesando ? null : _editar),
        ],
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
                Row(
                  children: [
                    Expanded(
                      child: Text(c.clienteNombre, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor)),
                    ),
                    EstatusChip(estatus: c.estatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  c.obraNombre ?? (c.obraId != null ? 'Obra #${c.obraId}' : 'Sin obra específica'),
                  style: TextStyle(fontSize: 13.5, color: mutedColor),
                ),
                const Divider(height: 24),
                _renglon('Asesor encargado', c.asesorNombre.isEmpty ? 'Sin asignar' : c.asesorNombre, textColor, mutedColor),
                _renglon(
                  'Contacto',
                  c.contactoId == null ? 'Sin contacto específico' : (_nombreContacto(c.contactoId) ?? 'Contacto #${c.contactoId}'),
                  textColor,
                  mutedColor,
                ),
                _renglon('Volumen total', '${c.volumenM3} m³', textColor, mutedColor),
                if (c.porcentajeDescuento > 0)
                  _renglon('Descuento', '${c.porcentajeDescuento}% (\$${c.precioUnitarioConDescuento.toStringAsFixed(2)} c/u)', textColor, mutedColor),
                _renglon('Monto total', '\$${c.montoTotal.toStringAsFixed(2)}', textColor, mutedColor),
                if (c.tipoServicio != null) _renglon('Tipo de servicio', tipoServicioLabel(c.tipoServicio), textColor, mutedColor),
                if (c.formaPago != null) _renglon('Forma de pago', formaPagoLabel(c.formaPago), textColor, mutedColor),
                _renglon('Requiere factura', c.requiereFactura ? 'Sí' : 'No', textColor, mutedColor),
                if (c.fechaSuministroEstimada != null)
                  _renglon('Suministro estimado', c.fechaSuministroEstimada!, textColor, mutedColor),
              ],
            ),
          ),
          if (c.productos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Partidas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            FieldGroup(
              cardColor: cardColor,
              borderColor: borderColor,
              expand: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < c.productos.length; i++) ...[
                    if (i > 0) const Divider(height: 24),
                    _partidaRow(c.productos[i], textColor, mutedColor),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_procesando)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (c.estatus == 'negociacion') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _actualizarEstatus('listo'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar como lista'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (c.estatus == 'listo') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _convertirAPedido,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Convertir a pedido'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (c.estatus != 'convertida' && c.estatus != 'cancelada') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmarCancelar,
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                  label: const Text('Cancelar cotización', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _duplicar,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Duplicar para renegociar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _partidaRow(CotizacionItem item, Color textColor, Color mutedColor) {
    final nombreProducto = _nombreProducto(item.productoId);
    final subtitulo = nombreProducto ?? item.descripcion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tipoLineaLabel(item.tipoLinea),
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textColor),
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 2),
          Text(subtitulo, style: TextStyle(fontSize: 12.5, color: mutedColor)),
        ],
        const SizedBox(height: 6),
        if (item.volumenM3 != null) _renglon('Volumen', '${item.volumenM3} m³', textColor, mutedColor),
        _renglon('Precio unitario', '\$${item.precioUnitario.toStringAsFixed(2)}', textColor, mutedColor),
        if (item.precioTotal != null) _renglon('Precio total', '\$${item.precioTotal!.toStringAsFixed(2)}', textColor, mutedColor),
      ],
    );
  }

  Widget _renglon(String label, String value, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: mutedColor))),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}

class _ConversionInput {
  final DateTime fechaProgramada;
  final String condicionPago;
  final int? diasCredito;

  const _ConversionInput({required this.fechaProgramada, required this.condicionPago, this.diasCredito});
}

class _ConvertirPedidoDialog extends StatefulWidget {
  final DateTime fechaSugerida;

  const _ConvertirPedidoDialog({required this.fechaSugerida});

  @override
  State<_ConvertirPedidoDialog> createState() => _ConvertirPedidoDialogState();
}

class _ConvertirPedidoDialogState extends State<_ConvertirPedidoDialog> {
  late DateTime _fecha;
  final _condicionPagoController = TextEditingController();
  final _diasCreditoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fecha = widget.fechaSugerida;
  }

  @override
  void dispose() {
    _condicionPagoController.dispose();
    _diasCreditoController.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Convertir a pedido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickFecha,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Fecha programada: ${DateFormat('d/MM/y').format(_fecha)}'),
            ),
          ),
          TextField(
            controller: _condicionPagoController,
            decoration: const InputDecoration(hintText: 'Condición de pago'),
          ),
          TextField(
            controller: _diasCreditoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Días de crédito (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (_condicionPagoController.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              _ConversionInput(
                fechaProgramada: _fecha,
                condicionPago: _condicionPagoController.text.trim(),
                diasCredito: int.tryParse(_diasCreditoController.text.trim()),
              ),
            );
          },
          child: const Text('Convertir'),
        ),
      ],
    );
  }
}
