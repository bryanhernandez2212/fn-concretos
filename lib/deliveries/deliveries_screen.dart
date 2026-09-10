import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/header_icon_button.dart';
import '../widgets/notification_bell_button.dart';
import 'delivery_detail_screen.dart';
import 'deliveries_widgets.dart';
import 'entregas_service.dart';
import 'historial_entregas_screen.dart';
import 'proximas_entregas_screen.dart';
import 'remision.dart';
import 'todas_rutas_screen.dart';

const _accentYellow = AppColors.accent;

/// "Mis entregas del día" — the operador de olla's main tab: every pedido
/// programado today that's actually assigned to this conductor (see
/// `EntregasService.entregasDelDia`). Tapping one opens its detail.
class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  late Future<List<Remision>> _future;

  /// Last successfully loaded list, kept around so a pull-to-refresh shows
  /// the existing entregas (with just `RefreshIndicator`'s own spinner up
  /// top) instead of blanking the whole screen to a second, redundant
  /// `CircularProgressIndicator` — that only renders on the very first load,
  /// before there's anything cached yet.
  List<Remision>? _ultimaData;

  @override
  void initState() {
    super.initState();
    _future = EntregasService.entregasDelDia();
  }

  /// Awaits the new fetch (not just kicks it off) so the pull-to-refresh
  /// spinner stays up for the actual round trip instead of vanishing before
  /// the list below has new data.
  Future<void> _refrescar() async {
    final future = EntregasService.entregasDelDia();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (e) {
      // A refresh failing while we already have a list on screen shouldn't
      // blank it out — just let the driver know and keep showing the stale
      // data. A failure on the very first load has no data to fall back to,
      // so that case is left to the FutureBuilder's own error state below.
      if (mounted && _ultimaData != null) {
        AppSnack.error(
          context,
          e is AuthException ? e.message : 'No se pudo actualizar la lista',
        );
      }
    }
  }

  /// Lower rank sorts first. A remisión with no resolved hito (`con_atraso`)
  /// or one flagged `conIncidencia` needs attention regardless of its
  /// horaProgramada, so both jump ahead of the plain hora-programada order
  /// everything else sorts by.
  int _rangoPrioridad(Remision r) =>
      (r.hitoActual == null || r.hitoActual == HitoEntrega.conIncidencia)
      ? 0
      : 1;

  List<Remision> _ordenPorPrioridad(List<Remision> pendientes) {
    final copia = [...pendientes];
    copia.sort((a, b) {
      final rango = _rangoPrioridad(a).compareTo(_rangoPrioridad(b));
      return rango != 0 ? rango : a.horaProgramada.compareTo(b.horaProgramada);
    });
    return copia;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.55,
    );
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return RefreshIndicator(
      onRefresh: _refrescar,
      // RefreshIndicator needs a scrollable descendant present in every
      // state (loading/error included), or the pull gesture has nothing to
      // attach to — so this ListView is always returned, varying only what
      // goes inside it, instead of swapping in a bare Center widget.
      child: FutureBuilder<List<Remision>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            _ultimaData = snapshot.data;
          }
          final tieneCache = _ultimaData != null;
          // Only the very first load (nothing cached yet) blanks the screen
          // to a spinner/error — once there's a cached list, a refresh in
          // flight or a refresh that failed both just keep showing it.
          final loading =
              snapshot.connectionState != ConnectionState.done && !tieneCache;
          final error = !loading && !tieneCache && snapshot.hasError;
          final entregas = _ultimaData ?? const <Remision>[];
          // Once entregada, a remisión has nothing left to do here — it
          // stays visible in "Historial de entregas" (same live data, just
          // queried for that date), not in today's working list.
          final pendientesList = entregas
              .where((r) => r.hitoActual != HitoEntrega.entregado)
              .toList();
          final pendientes = pendientesList.length;

          // Conteo de rutas for the dashboard summary. entregadasCount +
          // enRutaCount + pendientesCount always equals entregas.length by
          // construction — pendientesCount is "everything else" (not yet out
          // of planta, or conIncidencia/con_atraso needing attention) rather
          // than its own independently-filtered bucket.
          final entregadasCount = entregas
              .where((r) => r.hitoActual == HitoEntrega.entregado)
              .length;
          final enRutaCount = entregas
              .where((r) => HitoEntrega.enRutaHitos.contains(r.hitoActual))
              .length;
          final pendientesCount =
              entregas.length - entregadasCount - enRutaCount;
          final rutasPrioritarias = _ordenPorPrioridad(
            pendientesList,
          ).take(3).toList();

          String subtitulo;
          if (loading) {
            subtitulo = 'Cargando...';
          } else if (error) {
            subtitulo = snapshot.error is AuthException
                ? (snapshot.error as AuthException).message
                : 'No se pudieron cargar tus entregas';
          } else if (entregas.isEmpty) {
            subtitulo = 'No tienes entregas asignadas hoy';
          } else if (pendientesList.isEmpty) {
            subtitulo = 'Ya entregaste todos tus pedidos de hoy';
          } else {
            subtitulo = '$pendientes pendientes de ${entregas.length}';
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              BottomNavBar.clearance(context) + 16,
            ),
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accentYellow.withValues(alpha: 0.18),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: _accentYellow,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis entregas del día',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          subtitulo,
                          style: TextStyle(fontSize: 13, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  HeaderIconButton(
                    icon: Icons.history,
                    tooltip: 'Historial de entregas',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const HistorialEntregasScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  const NotificationBellButton(),
                ],
              ),
              const SizedBox(height: 20),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!error) ...[
                // Shown even with all-zero counts (no rutas asignadas hoy at
                // all) — this is the dashboard's summary, so it should always
                // have visible structure rather than disappearing along with
                // the list below once there's nothing pending.
                RutasResumenCard(
                  asignadas: entregas.length,
                  enRuta: enRutaCount,
                  entregadas: entregadasCount,
                  pendientes: pendientesCount,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rutas prioritarias',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    // Only worth a "ver todas" once there's more to see than
                    // what's already shown below — with 3 or fewer pendientes,
                    // the priority list below already is the whole list.
                    if (rutasPrioritarias.length < pendientesList.length)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TodasLasRutasScreen(),
                                ),
                              )
                              .then((_) => _refrescar());
                        },
                        child: const Text('Ver todas'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (pendientesList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 20),
                    child: Column(
                      children: [
                        Icon(
                          entregas.isEmpty
                              ? Icons.event_outlined
                              : Icons.check_circle_outline,
                          size: 40,
                          color: mutedColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          entregas.isEmpty
                              ? 'No tienes rutas asignadas hoy'
                              : 'Ya entregaste todos tus pedidos de hoy',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: mutedColor),
                        ),
                        const SizedBox(height: 16),
                        // Nothing today: point forward to what's coming
                        // instead of a dead-end empty screen. Something
                        // already delivered today: point at the day's full
                        // list instead, to review what's done.
                        if (entregas.isEmpty)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ProximasEntregasScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.event_outlined, size: 18),
                            label: const Text('Ver próximas entregas'),
                          )
                        else
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TodasLasRutasScreen(),
                                    ),
                                  )
                                  .then((_) => _refrescar());
                            },
                            icon: const Icon(
                              Icons.local_shipping_outlined,
                              size: 18,
                            ),
                            label: const Text('Ver todas las entregas de hoy'),
                          ),
                      ],
                    ),
                  )
                else
                  for (final remision in rutasPrioritarias) ...[
                    RemisionCard(
                      remision: remision,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    DeliveryDetailScreen(remision: remision),
                              ),
                            )
                            // A driver can finish the delivery (reach
                            // "entregado") inside the detail screen — refresh
                            // so it drops out of this list without needing a
                            // manual pull-to-refresh.
                            .then((_) => _refrescar());
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ],
          );
        },
      ),
    );
  }
}
