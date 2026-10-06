import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/auth_service.dart';
import '../../comercial/comercial_service.dart';
import '../../comercial/pedido.dart';
import '../../finanzas/facturacion.dart';
import '../../finanzas/finanzas_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/field_group.dart';
import '../cotizaciones/cotizacion.dart';
import 'pedidos_widgets.dart';

final _moneda = NumberFormat('#,##0.00', 'es_MX');

/// The advisor's pedido view, with the same actions as the web's pedido
/// page: "Enviar seguimiento por WhatsApp", "Generar prefactura" (only once
/// something was delivered and there's no live prefactura yet) and "Ver
/// prefactura", which opens its public printable page. Deliberately not
/// Dirección's `PedidoDetailScreen`, which carries the authorization actions.
class PedidoAsesorDetailScreen extends StatefulWidget {
  final Pedido pedido;

  const PedidoAsesorDetailScreen({super.key, required this.pedido});

  @override
  State<PedidoAsesorDetailScreen> createState() => _PedidoAsesorDetailScreenState();
}

class _PedidoAsesorDetailScreenState extends State<PedidoAsesorDetailScreen> {
  late Pedido _pedido = widget.pedido;
  double? _montoPagado;
  List<Prefactura>? _prefacturas;
  bool _enviandoWhatsApp = false;
  bool _generando = false;
  int? _abriendoPrefacturaId;

  @override
  void initState() {
    super.initState();
    _refrescar();
  }

  /// Best-effort — the list row is already enough to render.
  Future<void> _refrescar() async {
    await Future.wait([
      () async {
        try {
          final pedido = await ComercialService.obtenerPedido(widget.pedido.id);
          if (mounted) setState(() => _pedido = pedido);
        } catch (_) {}
      }(),
      () async {
        try {
          final pagado = await FinanzasService.pagadoPorPedido([widget.pedido.id]);
          if (mounted) setState(() => _montoPagado = pagado[widget.pedido.id] ?? 0);
        } catch (_) {}
      }(),
      _cargarPrefacturas(),
    ]);
  }

  Future<void> _cargarPrefacturas() async {
    try {
      final prefacturas = await FinanzasService.prefacturasDePedido(widget.pedido.id);
      if (mounted) setState(() => _prefacturas = prefacturas);
    } catch (_) {}
  }

  Prefactura? get _prefacturaActiva {
    for (final p in _prefacturas ?? const <Prefactura>[]) {
      if (p.activa) return p;
    }
    return null;
  }

  Future<void> _enviarSeguimiento() async {
    setState(() => _enviandoWhatsApp = true);
    try {
      final telefono = await ComercialService.enviarSeguimientoWhatsApp(_pedido.id);
      if (!mounted) return;
      AppSnack.success(
        context,
        telefono == null ? 'Seguimiento enviado por WhatsApp' : 'Seguimiento enviado por WhatsApp a $telefono',
      );
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo enviar el seguimiento por WhatsApp');
    } finally {
      if (mounted) setState(() => _enviandoWhatsApp = false);
    }
  }

  Future<void> _generarPrefactura() async {
    setState(() => _generando = true);
    try {
      final prefactura = await FinanzasService.generarPrefacturaPedido(_pedido.id);
      if (!mounted) return;
      AppSnack.success(context, 'Prefactura ${prefactura.folio} generada por \$${_moneda.format(prefactura.montoTotal)}');
      await _cargarPrefacturas();
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo generar la prefactura');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _verPrefactura(Prefactura prefactura) async {
    setState(() => _abriendoPrefacturaId = prefactura.id);
    try {
      final liga = await FinanzasService.ligaPublicaPrefactura(prefactura.id);
      final abierta = await launchUrl(liga, mode: LaunchMode.externalApplication);
      if (!abierta && mounted) AppSnack.error(context, 'No se pudo abrir la prefactura');
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo abrir la prefactura');
    } finally {
      if (mounted) setState(() => _abriendoPrefacturaId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);
    final p = _pedido;
    final monto = p.montoTotal;
    final pagado = _montoPagado == null ? null : pedidoPagado(p, {p.id: _montoPagado!});
    final activa = _prefacturaActiva;
    final puedeGenerar = p.volumenEntregadoM3 > 0 && activa == null && _prefacturas != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.folio),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: ListView(
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
                        child: Text(
                          p.clienteNombre,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor),
                        ),
                      ),
                      EstatusBadge(label: estatusTexto(p.estatusGeneral), color: estatusTono(p.estatusGeneral)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(p.obraNombre, style: TextStyle(fontSize: 13.5, color: mutedColor)),
                  const Divider(height: 24),
                  _renglon('Volumen solicitado', '${p.volumenSolicitadoM3} m³', textColor, mutedColor),
                  if (p.volumenEntregadoM3 > 0) ...[
                    _renglon('Entregado', '${p.volumenEntregadoM3} m³', textColor, mutedColor),
                    _renglon('Pendiente', '${p.volumenPendienteM3} m³', textColor, mutedColor),
                  ],
                  if (p.tipoServicio.isNotEmpty)
                    _renglon('Tipo de servicio', tipoServicioLabel(p.tipoServicio), textColor, mutedColor),
                  if (p.fechaProgramada != null)
                    _renglon('Fecha programada', fechaCorta(p.fechaProgramada), textColor, mutedColor),
                  if (p.condicionPago.isNotEmpty)
                    _renglon(
                      'Condición de pago',
                      condicionPagoLabel(p.condicionPago, diasCredito: p.diasCredito),
                      textColor,
                      mutedColor,
                    ),
                  if (p.formaPago != null)
                    _renglon(
                      'Forma de pago',
                      metodoPagoOpciones[p.formaPago] ?? estatusTexto(p.formaPago),
                      textColor,
                      mutedColor,
                    ),
                  if (monto != null) _renglon('Monto total', '\$${_moneda.format(monto)}', textColor, mutedColor),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _titulo('Autorizaciones y cobro', textColor),
            const SizedBox(height: 8),
            FieldGroup(
              cardColor: cardColor,
              borderColor: borderColor,
              expand: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _renglonBadge(
                    'Autorización de pago',
                    EstatusBadge(
                      label: estatusTexto(p.estatusPagoAutorizacion),
                      color: estatusTono(p.estatusPagoAutorizacion),
                    ),
                    mutedColor,
                  ),
                  _renglonBadge(
                    'Autorización de logística',
                    EstatusBadge(
                      label: estatusTexto(p.estatusLogisticaAutorizacion),
                      color: estatusTono(p.estatusLogisticaAutorizacion),
                    ),
                    mutedColor,
                  ),
                  if (pagado != null)
                    _renglonBadge(
                      'Estatus de pago',
                      EstatusBadge(
                        label: pagado ? 'Pagado' : 'Pendiente de pago',
                        color: pagado ? AppColors.success : AppColors.warning,
                      ),
                      mutedColor,
                    ),
                  if (_montoPagado != null && monto != null)
                    _renglon(
                      'Pagado',
                      '\$${_moneda.format(_montoPagado)} de \$${_moneda.format(monto)}',
                      textColor,
                      mutedColor,
                    ),
                  if (p.motivoRechazo != null && p.motivoRechazo!.isNotEmpty)
                    _renglon('Motivo de rechazo', p.motivoRechazo!, textColor, mutedColor),
                ],
              ),
            ),
            if (_prefacturas != null && _prefacturas!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _titulo('Prefacturas de este pedido', textColor),
              const SizedBox(height: 8),
              FieldGroup(
                cardColor: cardColor,
                borderColor: borderColor,
                expand: true,
                child: Column(
                  children: [
                    for (var i = 0; i < _prefacturas!.length; i++) ...[
                      if (i > 0) const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _prefacturas![i].folio,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                                ),
                                Text(
                                  '\$${_moneda.format(_prefacturas![i].montoTotal)}',
                                  style: TextStyle(fontSize: 12.5, color: mutedColor),
                                ),
                              ],
                            ),
                          ),
                          EstatusBadge(
                            label: estatusTexto(_prefacturas![i].estatus),
                            color: _prefacturas![i].estatus == 'borrador'
                                ? AppColors.neutral
                                : estatusTono(_prefacturas![i].estatus),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (p.productos.isNotEmpty) ...[
              const SizedBox(height: 16),
              _titulo('Partidas', textColor),
              const SizedBox(height: 8),
              FieldGroup(
                cardColor: cardColor,
                borderColor: borderColor,
                expand: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < p.productos.length; i++) ...[
                      if (i > 0) const Divider(height: 24),
                      _partidaRow(p.productos[i], textColor, mutedColor),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _BotonAccion(
              icon: Icons.chat_outlined,
              label: _enviandoWhatsApp ? 'Enviando…' : 'Enviar seguimiento por WhatsApp',
              cargando: _enviandoWhatsApp,
              primario: true,
              onPressed: _enviandoWhatsApp ? null : _enviarSeguimiento,
              textColor: textColor,
              borderColor: borderColor,
            ),
            if (puedeGenerar) ...[
              const SizedBox(height: 10),
              _BotonAccion(
                icon: Icons.receipt_long_outlined,
                label: _generando ? 'Generando…' : 'Generar prefactura',
                cargando: _generando,
                onPressed: _generando ? null : _generarPrefactura,
                textColor: textColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 6),
              Text(
                'Genera la prefactura de todo el pedido, vinculando sus remisiones entregadas/firmadas.',
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            ],
            if (activa != null) ...[
              const SizedBox(height: 10),
              _BotonAccion(
                icon: Icons.print_outlined,
                label: _abriendoPrefacturaId == activa.id ? 'Abriendo…' : 'Ver / imprimir prefactura ${activa.folio}',
                cargando: _abriendoPrefacturaId == activa.id,
                onPressed: _abriendoPrefacturaId != null ? null : () => _verPrefactura(activa),
                textColor: textColor,
                borderColor: borderColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto, Color textColor) =>
      Text(texto, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor));

  Widget _partidaRow(PedidoItem item, Color textColor, Color mutedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tipoLineaLabel(item.tipoLinea),
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textColor),
        ),
        if (item.descripcion != null) ...[
          const SizedBox(height: 2),
          Text(item.descripcion!, style: TextStyle(fontSize: 12.5, color: mutedColor)),
        ],
        const SizedBox(height: 6),
        if (item.volumenSolicitadoM3 != null)
          _renglon('Volumen', '${item.volumenSolicitadoM3} m³', textColor, mutedColor),
        if (item.precioUnitario != null)
          _renglon('Precio unitario', '\$${_moneda.format(item.precioUnitario)}', textColor, mutedColor),
        if (item.precioTotal != null)
          _renglon('Precio total', '\$${_moneda.format(item.precioTotal)}', textColor, mutedColor),
      ],
    );
  }

  Widget _renglonBadge(String label, Widget badge, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: mutedColor))),
          badge,
        ],
      ),
    );
  }

  Widget _renglon(String label, String value, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: mutedColor))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool cargando;
  final bool primario;
  final VoidCallback? onPressed;
  final Color textColor;
  final Color borderColor;

  const _BotonAccion({
    required this.icon,
    required this.label,
    required this.cargando,
    this.primario = false,
    required this.onPressed,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = cargando
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: primario ? Colors.black : textColor),
          )
        : Icon(icon);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const padding = EdgeInsets.symmetric(vertical: 16);
    return SizedBox(
      width: double.infinity,
      child: primario
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: iconWidget,
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.black,
                padding: padding,
                elevation: 0,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                shape: shape,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: iconWidget,
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: borderColor),
                padding: padding,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                shape: shape,
              ),
            ),
    );
  }
}
