import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../catalogo/catalogo_service.dart';
import '../../finanzas/finanzas_service.dart';
import '../../finanzas/orden_compra.dart';
import '../../operaciones/operaciones_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import 'ordenes_compra_widgets.dart';

/// Detail of one orden de compra (`GET /ordenes-compra/{id}`, with items)
/// plus its bitácora, and — while it's still [OrdenCompra.porAutorizar] and
/// the session holds [permisoAutorizarOrdenesCompra] — Autorizar/Rechazar.
/// Pops `true` after either action so the list refreshes.
class OrdenCompraDetailScreen extends StatefulWidget {
  final int ordenId;

  const OrdenCompraDetailScreen({super.key, required this.ordenId});

  @override
  State<OrdenCompraDetailScreen> createState() =>
      _OrdenCompraDetailScreenState();
}

class _OrdenCompraDetailScreenState extends State<OrdenCompraDetailScreen> {
  late Future<OrdenCompra> _ordenFuture = FinanzasService.ordenCompra(
    widget.ordenId,
  );
  late final Future<List<OrdenCompraBitacora>> _bitacoraFuture =
      FinanzasService.bitacoraOrdenCompra(widget.ordenId);

  // plantaId / vehiculoDestinoId come back as bare ids — resolved to names
  // best-effort; a failed lookup just shows the id.
  late final Future<String?> _plantaFuture = _ordenFuture.then((o) async {
    if (o.plantaId == null) return null;
    try {
      final plantas = await CatalogoService.plantas();
      for (final p in plantas) {
        if (p.id == o.plantaId) return p.nombre;
      }
    } catch (_) {}
    return 'Planta ${o.plantaId}';
  });
  late final Future<String?> _vehiculoFuture = _ordenFuture.then((o) async {
    if (o.vehiculoDestinoId == null) return null;
    try {
      return (await OperacionesService.vehiculo(
        o.vehiculoDestinoId!,
      )).numeroUnidad;
    } catch (_) {
      return 'Vehículo ${o.vehiculoDestinoId}';
    }
  });

  bool _enviando = false;

  bool get _puedeAutorizar =>
      AuthService.permisos.contains(permisoAutorizarOrdenesCompra);

  Future<void> _autorizar(OrdenCompra orden) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Autorizar orden de compra',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '¿Autorizar ${orden.folio} de ${orden.proveedorNombre} por ${moneda.format(orden.total)}?',
          style: TextStyle(color: AppColors.mutedText(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.mutedText(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Autorizar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _ejecutar(
      () => FinanzasService.autorizarOrdenCompra(orden.id),
      'Orden autorizada',
    );
  }

  Future<void> _rechazar(OrdenCompra orden) async {
    final motivoController = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Motivo del rechazo',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: motivoController,
          autofocus: true,
          maxLines: 3,
          style: TextStyle(color: AppColors.text(context)),
          decoration: InputDecoration(
            hintText: 'Explica por qué se rechaza...',
            hintStyle: TextStyle(color: AppColors.mutedText(context)),
            filled: true,
            fillColor: AppColors.text(context).withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.mutedText(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final texto = motivoController.text.trim();
              if (texto.isNotEmpty) Navigator.of(context).pop(texto);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Rechazar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (motivo == null) return;
    await _ejecutar(
      () => FinanzasService.rechazarOrdenCompra(orden.id, motivo: motivo),
      'Orden rechazada',
    );
  }

  Future<void> _ejecutar(
    Future<OrdenCompra> Function() accion,
    String exito,
  ) async {
    setState(() => _enviando = true);
    try {
      await accion();
      if (!mounted) return;
      AppSnack.success(context, exito);
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnack.error(context, e.message);
      setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    return FutureBuilder<OrdenCompra>(
      future: _ordenFuture,
      builder: (context, snapshot) {
        final orden = snapshot.data;
        final mostrarAcciones =
            orden != null && orden.porAutorizar && _puedeAutorizar;

        Widget body;
        if (snapshot.connectionState != ConnectionState.done) {
          body = const Center(child: CircularProgressIndicator());
        } else if (orden == null) {
          body = Padding(
            padding: const EdgeInsets.all(20),
            child: OrdenesCompraMensaje(
              icon: Icons.error_outline,
              iconColor: Colors.redAccent,
              mensaje: snapshot.error is AuthException
                  ? (snapshot.error as AuthException).message
                  : 'No se pudo cargar la orden de compra',
              onRetry: () => setState(
                () =>
                    _ordenFuture = FinanzasService.ordenCompra(widget.ordenId),
              ),
            ),
          );
        } else {
          body = ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            orden.folio,
                            style: TextStyle(fontSize: 13, color: mutedColor),
                          ),
                        ),
                        EstatusOrdenChip(estatus: orden.estatus),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      orden.proveedorNombre,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      moneda.format(orden.total),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      orden.facturacionConIva
                          ? 'Total con IVA'
                          : 'Total sin IVA',
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                    if (orden.motivoRechazo != null &&
                        orden.motivoRechazo!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Motivo de rechazo: ${orden.motivoRechazo}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<String?>>(
                future: Future.wait([_plantaFuture, _vehiculoFuture]),
                builder: (context, nombresSnap) {
                  final planta = nombresSnap.data?[0];
                  final vehiculo = nombresSnap.data?[1];
                  final destino = [
                    if (orden.destinoTipo != null)
                      etiquetaEstatusOrdenCompra(orden.destinoTipo!),
                    if (vehiculo != null) vehiculo,
                    if (orden.areaDestino != null &&
                        orden.areaDestino!.isNotEmpty)
                      orden.areaDestino!,
                  ].join(' · ');
                  return OrdenSeccion(
                    titulo: 'Datos de la orden',
                    children: [
                      OrdenDatoRow(
                        label: 'Planta',
                        value: planta ?? (orden.plantaId == null ? '' : '...'),
                      ),
                      OrdenDatoRow(
                        label: 'Condición de pago',
                        value: orden.condicionPago ?? '',
                      ),
                      OrdenDatoRow(label: 'Destino', value: destino),
                      OrdenDatoRow(
                        label: 'Solicitó',
                        value: orden.creadoPorUsuario ?? '',
                      ),
                      OrdenDatoRow(
                        label: 'Fecha',
                        value: fechaCorta(orden.createdAt),
                      ),
                    ],
                  );
                },
              ),
              OrdenSeccion(
                titulo: 'Partidas (${orden.items.length})',
                children: [
                  if (orden.items.isEmpty)
                    const OrdenDatoRow(label: 'Sin partidas', value: '')
                  else
                    for (var i = 0; i < orden.items.length; i++)
                      OrdenItemRow(
                        item: orden.items[i],
                        isLast: i == orden.items.length - 1,
                      ),
                  Divider(height: 1, color: mutedColor.withValues(alpha: 0.3)),
                  OrdenDatoRow(
                    label: 'Subtotal',
                    value: moneda.format(orden.subtotal),
                  ),
                  OrdenDatoRow(label: 'IVA', value: moneda.format(orden.iva)),
                  OrdenDatoRow(
                    label: 'Total',
                    value: moneda.format(orden.total),
                    bold: true,
                  ),
                ],
              ),
              FutureBuilder<List<OrdenCompraBitacora>>(
                future: _bitacoraFuture,
                builder: (context, bitSnap) {
                  final eventos = bitSnap.data;
                  if (eventos == null || eventos.isEmpty)
                    return const SizedBox.shrink();
                  return OrdenSeccion(
                    titulo: 'Historial',
                    children: [
                      for (final e in eventos)
                        OrdenDatoRow(
                          label:
                              '${fechaCorta(e.createdAt)}${e.usuario == null ? '' : ' · ${e.usuario}'}',
                          value:
                              etiquetaEstatusOrdenCompra(e.estatusNuevo) +
                              (e.comentario == null || e.comentario!.isEmpty
                                  ? ''
                                  : '\n${e.comentario}'),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Orden de compra'),
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 0,
          ),
          body: body,
          bottomNavigationBar: !mostrarAcciones
              ? null
              : SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                        top: BorderSide(color: AppColors.border(context)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _enviando
                                ? null
                                : () => _rechazar(orden),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Rechazar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _enviando
                                ? null
                                : () => _autorizar(orden),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Autorizar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
