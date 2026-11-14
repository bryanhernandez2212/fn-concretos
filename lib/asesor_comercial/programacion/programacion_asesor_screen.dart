import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../comercial/pedido.dart';
import '../../operaciones/operaciones_service.dart';
import '../../operaciones/produccion.dart';
import '../../operaciones/remision_tracking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/notification_bell_button.dart';
import '../asesor_comercial_service.dart';
import '../asesor_comercial_widgets.dart';
import '../cotizaciones/cotizacion.dart';
import '../cotizaciones/cotizacion_detail_screen.dart';
import '../pedidos/pedido_asesor_detail_screen.dart';
import 'programacion_widgets.dart';
import 'seguimiento_mapa_screen.dart';

enum _Filtro { previas, programadas, todas }

/// A programación row joined with the asesor's pedido or cotización.
class _Item {
  final ProgramacionFila fila;
  final Pedido? pedido;
  final Cotizacion? cotizacion;

  const _Item(this.fila, this.pedido, this.cotizacion);

  /// Rows that are on the planta's schedule and belong to a pedido: the
  /// ones that get the "where is it" tracker.
  bool get seguible => pedido != null && (fila.estatus == 'programado' || fila.estatus == 'aprobado');

  String get folio => pedido?.folio ?? cotizacion?.folio ?? 'Programación #${fila.id}';
  String? get cliente => pedido?.clienteNombre ?? cotizacion?.clienteNombre;
  String? get obra => pedido?.obraNombre ?? cotizacion?.obraNombre;
  double? get volumen => pedido?.volumenSolicitadoM3 ?? cotizacion?.volumenM3;
}

/// "Programación" tab: read-only view of the previa and programación rows
/// (operaciones `GET /programacion-produccion`, all fechas) that belong to
/// the advisor's own pedidos and cotizaciones. The endpoint has no asesor
/// filter, so rows are joined client-side with `misPedidos`/`misCotizaciones`
/// and the rest are dropped. Changing a row's estatus is the planta's job.
class ProgramacionAsesorScreen extends StatefulWidget {
  const ProgramacionAsesorScreen({super.key});

  @override
  State<ProgramacionAsesorScreen> createState() => _ProgramacionAsesorScreenState();
}

class _ProgramacionAsesorScreenState extends State<ProgramacionAsesorScreen> {
  late Future<List<_Item>> _future;
  _Filtro _filtro = _Filtro.previas;
  final _busquedaController = TextEditingController();

  /// The pedido's remisiones by pedidoId, for the tracker. Best-effort: a
  /// pedido whose lookup failed has no entry and shows no tracker.
  final Map<int, List<RemisionResumen>> _remisiones = {};
  List<_Item> _items = const [];
  Timer? _timer;

  static const _intervalo = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _future = _cargar();
    _timer = Timer.periodic(_intervalo, (_) {
      if (_filtro != _Filtro.previas) _cargarRemisiones();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  Future<List<_Item>> _cargar() async {
    final asesor = await AsesorComercialService.miAsesor();
    if (asesor == null) {
      throw AuthException('No se encontró un asesor comercial vinculado a esta cuenta');
    }
    final resultados = await Future.wait([
      OperacionesService.programacionesDe(),
      AsesorComercialService.misPedidos(asesorId: asesor.id),
      AsesorComercialService.misCotizaciones(asesorId: asesor.id),
    ]);
    final filas = resultados[0] as List<ProgramacionFila>;
    final pedidos = {for (final p in resultados[1] as List<Pedido>) p.id: p};
    final cotizaciones = {for (final c in resultados[2] as List<Cotizacion>) c.id: c};

    final items = <_Item>[];
    for (final f in filas) {
      final pedido = pedidos[f.pedidoId];
      final cotizacion = cotizaciones[f.cotizacionId];
      if (pedido != null || cotizacion != null) items.add(_Item(f, pedido, cotizacion));
    }
    items.sort((a, b) => (b.fila.fechaProgramada ?? '').compareTo(a.fila.fechaProgramada ?? ''));
    _items = items;
    _cargarRemisiones();
    return items;
  }

  /// Best-effort, one lookup per scheduled pedido, in parallel. The
  /// remisión's own hito (set by the driver's app) is the source of truth.
  Future<void> _cargarRemisiones() async {
    final ids = {for (final i in _items.where((i) => i.seguible)) i.pedido!.id};
    await Future.wait([
      for (final id in ids)
        () async {
          try {
            final remisiones = await OperacionesService.remisionesPorPedido(id);
            if (mounted) setState(() => _remisiones[id] = remisiones);
          } catch (_) {}
        }(),
    ]);
  }

  void _refresh() => setState(() => _future = _cargar());

  bool _enFiltro(_Item i, _Filtro filtro) => switch (filtro) {
    _Filtro.previas => i.fila.estatus == 'previa',
    _Filtro.programadas => i.fila.estatus == 'programado' || i.fila.estatus == 'aprobado',
    _Filtro.todas => true,
  };

  bool _coincideBusqueda(_Item i) {
    final q = _busquedaController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return i.folio.toLowerCase().contains(q) ||
        (i.cliente ?? '').toLowerCase().contains(q) ||
        (i.obra ?? '').toLowerCase().contains(q);
  }

  void _abrir(_Item i) async {
    final pedido = i.pedido;
    final cotizacion = i.cotizacion;
    if (pedido != null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PedidoAsesorDetailScreen(pedido: pedido)),
      );
    } else if (cotizacion != null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => CotizacionDetailScreen(cotizacion: cotizacion)),
      );
    }
    if (mounted) _refresh();
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
      child: FutureBuilder<List<_Item>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <_Item>[];
          final cargando = snapshot.connectionState != ConnectionState.done;
          final visibles = items.where((i) => _enFiltro(i, _filtro) && _coincideBusqueda(i)).toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, BottomNavBar.clearance(context) + 16),
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.18)),
                    child: Icon(Icons.event_note_outlined, color: AppColors.accentFg(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Programación', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                        Text(
                          'Previa y programación de tus pedidos',
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
                  hintText: 'Buscar folio, cliente u obra',
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
                    borderSide: BorderSide(color: AppColors.accentFg(context), width: 1.5),
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
                      (_Filtro.previas, 'Previas'),
                      (_Filtro.programadas, 'Programadas'),
                      (_Filtro.todas, 'Todas'),
                    ]) ...[
                      ChoiceChip(
                        label: Text(cargando ? label : '$label  ${items.where((i) => _enFiltro(i, filtro)).length}'),
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
                      : 'No se pudo cargar la programación',
                  onRetry: _refresh,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                )
              else if (visibles.isEmpty)
                EmptyState(
                  message: items.isEmpty
                      ? 'Aún no hay previas ni programaciones de tus pedidos.'
                      : 'No hay registros con este filtro',
                  icon: Icons.event_note_outlined,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                )
              else
                for (final item in visibles) ...[
                  ProgramacionAsesorCard(
                    fila: item.fila,
                    folio: item.folio,
                    esPedido: item.pedido != null,
                    cliente: item.cliente,
                    obra: item.obra,
                    volumenM3: item.volumen,
                    remisiones: item.seguible ? _remisiones[item.pedido!.id] : null,
                    onVerMapa: item.seguible
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => SeguimientoMapaScreen(pedido: item.pedido!)),
                          )
                        : null,
                    onTap: () => _abrir(item),
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
