import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../comercial/pedido.dart';
import '../../finanzas/facturacion.dart';
import '../../finanzas/finanzas_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/notification_bell_button.dart';
import '../asesor_comercial_service.dart';
import '../asesor_comercial_widgets.dart';
import 'pedido_asesor_detail_screen.dart';
import 'pedidos_widgets.dart';

enum _Filtro { todos, pendientes, enProceso, completados }

/// "Pedidos" tab, modeled on the web's Pedidos page: the advisor's pedidos
/// (`GET /pedidos?asesorId=`) with the same Todos / Pendientes / En proceso /
/// Completados grouping and search. Pedidos are only created by converting
/// a cotización, so there's no "new" action here. Payment and facturación
/// badges come from finanzas' per-pedido summaries, best-effort.
class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  late Future<List<Pedido>> _future;
  Map<int, double>? _pagado;
  Map<int, PedidoFacturacionResumen>? _facturacion;
  _Filtro _filtro = _Filtro.todos;
  final _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<List<Pedido>> _cargar() async {
    final asesor = await AsesorComercialService.miAsesor();
    if (asesor == null) {
      throw AuthException('No se encontró un asesor comercial vinculado a esta cuenta');
    }
    final pedidos = await AsesorComercialService.misPedidos(asesorId: asesor.id);
    pedidos.sort((a, b) => b.id.compareTo(a.id));
    _cargarResumenes(pedidos.map((p) => p.id).toList());
    return pedidos;
  }

  Future<void> _cargarResumenes(List<int> ids) async {
    await Future.wait([
      () async {
        try {
          final pagado = await FinanzasService.pagadoPorPedido(ids);
          if (mounted) setState(() => _pagado = pagado);
        } catch (_) {}
      }(),
      () async {
        try {
          final facturacion = await FinanzasService.facturacionPorPedido(ids);
          if (mounted) setState(() => _facturacion = facturacion);
        } catch (_) {}
      }(),
    ]);
  }

  void _refresh() => setState(() => _future = _cargar());

  bool _enFiltro(Pedido p, _Filtro filtro) => switch (filtro) {
    _Filtro.todos => true,
    _Filtro.pendientes => pedidoPendiente(p),
    _Filtro.enProceso => pedidoEnProceso(p),
    _Filtro.completados => pedidoCompletado(p),
  };

  bool _coincideBusqueda(Pedido p) {
    final q = _busquedaController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return p.folio.toLowerCase().contains(q) ||
        p.clienteNombre.toLowerCase().contains(q) ||
        p.obraNombre.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.08);
    final fillColor = AppColors.border(context, alpha: 0.06);

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<Pedido>>(
        future: _future,
        builder: (context, snapshot) {
          final pedidos = snapshot.data ?? const <Pedido>[];
          final cargando = snapshot.connectionState != ConnectionState.done;
          final visibles = pedidos.where((p) => _enFiltro(p, _filtro) && _coincideBusqueda(p)).toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, BottomNavBar.clearance(context) + 16),
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.18)),
                    child: const Icon(Icons.assignment_outlined, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pedidos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                        Text(
                          cargando || snapshot.hasError
                              ? 'Se crean al convertir una cotización'
                              : '${pedidos.length} pedidos · se crean al convertir una cotización',
                          style: TextStyle(fontSize: 13, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  const NotificationBellButton(),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _busquedaController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Buscar pedido, cliente u obra',
                  hintStyle: TextStyle(color: mutedColor),
                  prefixIcon: Icon(Icons.search, color: mutedColor),
                  suffixIcon: _busquedaController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close, color: mutedColor),
                          onPressed: () => setState(_busquedaController.clear),
                        ),
                  filled: true,
                  fillColor: fillColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (filtro, label) in const [
                      (_Filtro.todos, 'Todos'),
                      (_Filtro.pendientes, 'Pendientes'),
                      (_Filtro.enProceso, 'En proceso'),
                      (_Filtro.completados, 'Completados'),
                    ]) ...[
                      ChoiceChip(
                        label: Text(
                          cargando ? label : '$label  ${pedidos.where((p) => _enFiltro(p, filtro)).length}',
                        ),
                        selected: _filtro == filtro,
                        onSelected: (_) => setState(() => _filtro = filtro),
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _filtro == filtro ? Colors.black : textColor,
                        ),
                        backgroundColor: fillColor,
                        side: BorderSide.none,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (cargando)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
              else if (snapshot.hasError)
                ErrorState(
                  message: snapshot.error is AuthException
                      ? (snapshot.error as AuthException).message
                      : 'No se pudieron cargar los pedidos',
                  onRetry: _refresh,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                )
              else if (visibles.isEmpty)
                EmptyState(
                  message: pedidos.isEmpty
                      ? 'Aún no tienes pedidos. Se crean al convertir una cotización lista.'
                      : 'No hay pedidos con este filtro',
                  icon: Icons.assignment_outlined,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                )
              else
                for (final pedido in visibles) ...[
                  PedidoAsesorCard(
                    pedido: pedido,
                    pagado: pedidoPagado(pedido, _pagado),
                    facturacion: _facturacion == null ? null : facturacionBadge(_facturacion![pedido.id]),
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () async {
                      await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (context) => PedidoAsesorDetailScreen(pedido: pedido)),
                      );
                      if (mounted) _refresh();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}
