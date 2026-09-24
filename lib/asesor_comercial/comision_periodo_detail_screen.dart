import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../direccion/comercial_service.dart';
import '../finanzas/comision.dart';
import '../finanzas/finanzas_service.dart';
import '../theme/app_colors.dart';
import '../widgets/field_group.dart';
import 'asesor_comercial_widgets.dart';
import 'comisiones_widgets.dart';

final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

/// One commission period's breakdown — each pedido counted toward it, with
/// its importe, porcentaje aplicado and comisión. Re-fetches the period
/// (`GET /comisiones-periodo/{id}`) rather than trusting the list's copy,
/// since its estatus/ajustes may have changed since the list loaded.
class ComisionPeriodoDetailScreen extends StatefulWidget {
  final ComisionPeriodo periodo;

  const ComisionPeriodoDetailScreen({super.key, required this.periodo});

  @override
  State<ComisionPeriodoDetailScreen> createState() => _ComisionPeriodoDetailScreenState();
}

class _ComisionPeriodoDetailScreenState extends State<ComisionPeriodoDetailScreen> {
  late Future<ComisionPeriodo> _future;

  /// Best-effort `pedidoId` → folio/cliente, so each row can say which
  /// pedido it is instead of a bare id; a failed lookup just shows the id.
  final Map<int, (String folio, String cliente)> _pedidos = {};

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<ComisionPeriodo> _cargar() async {
    final periodo = await FinanzasService.periodoComision(widget.periodo.id);
    _resolverPedidos(periodo);
    return periodo;
  }

  Future<void> _resolverPedidos(ComisionPeriodo periodo) async {
    final ids = periodo.detalle.map((d) => d.pedidoId).whereType<int>().toSet();
    await Future.wait(ids.map((id) async {
      try {
        final pedido = await ComercialService.obtenerPedido(id);
        if (mounted) setState(() => _pedidos[id] = (pedido.folio, pedido.clienteNombre));
      } catch (_) {}
    }));
  }

  void _refresh() => setState(() => _future = _cargar());

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Periodo de comisión'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: FutureBuilder<ComisionPeriodo>(
        future: _future,
        initialData: widget.periodo,
        builder: (context, snapshot) {
          if (snapshot.hasError && snapshot.connectionState == ConnectionState.done) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ErrorState(
                  message: snapshot.error is AuthException
                      ? (snapshot.error as AuthException).message
                      : 'No se pudo cargar el periodo',
                  onRetry: _refresh,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                ),
              ],
            );
          }
          final p = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _Grupo(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(periodoTexto(p), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
                        ),
                        ComisionEstatusChip(estatus: p.estatus),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Total de comisiones', style: TextStyle(fontSize: 12.5, color: mutedColor)),
                    const SizedBox(height: 4),
                    Text(_moneda.format(p.totalComisiones), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
                    if (p.fechaAutorizacion != null) ...[
                      const SizedBox(height: 10),
                      Text('Autorizado el ${fechaCorta(p.fechaAutorizacion!.split('T').first)}',
                          style: TextStyle(fontSize: 12.5, color: mutedColor)),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Text('Pedidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 12),
                if (p.detalle.isEmpty)
                  EmptyState(
                    message: 'Este periodo aún no tiene pedidos',
                    icon: Icons.receipt_long_outlined,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    mutedColor: mutedColor,
                  )
                else
                  for (final d in p.detalle) ...[
                    _DetalleCard(detalle: d, pedido: _pedidos[d.pedidoId], textColor: textColor, mutedColor: mutedColor),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetalleCard extends StatelessWidget {
  final ComisionDetalle detalle;
  final (String folio, String cliente)? pedido;
  final Color textColor;
  final Color mutedColor;

  const _DetalleCard({required this.detalle, required this.pedido, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final d = detalle;
    final titulo = pedido?.$1 ?? (d.pedidoId != null ? 'Pedido #${d.pedidoId}' : 'Pedido');
    return _Grupo(
      children: [
        Row(
          children: [
            Expanded(child: Text(titulo, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor))),
            Text(_moneda.format(d.comisionCalculada), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
          ],
        ),
        if (pedido != null) ...[
          const SizedBox(height: 2),
          Text(pedido!.$2, style: TextStyle(fontSize: 13, color: mutedColor)),
        ],
        const SizedBox(height: 10),
        if (d.importeTotal != null) _renglon('Importe del pedido', _moneda.format(d.importeTotal)),
        if (d.metrosSuministrados != null) _renglon('Metros suministrados', '${d.metrosSuministrados} m³'),
        if (d.tipoSuministro != null && d.tipoSuministro!.isNotEmpty) _renglon('Tipo de suministro', d.tipoSuministro!),
        if (d.porcentajeAplicado != null) _renglon('Porcentaje aplicado', '${d.porcentajeAplicado}%'),
        if (d.esCorporativo) _renglon('Cliente', 'Corporativo'),
        if (d.motivoAjuste != null && d.motivoAjuste!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text('Ajustada: ${d.motivoAjuste}', style: TextStyle(fontSize: 12.5, color: textColor)),
          ),
        ],
      ],
    );
  }

  Widget _renglon(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: mutedColor))),
          Text(valor, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}

/// [FieldGroup] with a start-aligned column of [children], full width.
class _Grupo extends StatelessWidget {
  final List<Widget> children;

  const _Grupo({required this.children});

  @override
  Widget build(BuildContext context) {
    return FieldGroup(
      expand: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
