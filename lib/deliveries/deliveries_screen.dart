import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/notification_bell_button.dart';
import 'delivery_detail_screen.dart';
import 'deliveries_widgets.dart';
import 'entregas_service.dart';
import 'historial_entregas_screen.dart';
import 'remision.dart';

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
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            _ultimaData = snapshot.data;
          }
          final tieneCache = _ultimaData != null;
          // Only the very first load (nothing cached yet) blanks the screen
          // to a spinner/error — once there's a cached list, a refresh in
          // flight or a refresh that failed both just keep showing it.
          final loading = snapshot.connectionState != ConnectionState.done && !tieneCache;
          final error = !loading && !tieneCache && snapshot.hasError;
          final entregas = _ultimaData ?? const <Remision>[];
          // Once entregada, a remisión has nothing left to do here — it
          // stays visible in "Historial de entregas" (same live data, just
          // queried for that date), not in today's working list.
          final pendientesList = entregas
              .where((r) => r.hitoActual != HitoEntrega.entregado)
              .toList();
          final pendientes = pendientesList.length;

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
                  const NotificationBellButton(),
                  IconButton(
                    tooltip: 'Historial de entregas',
                    icon: Icon(Icons.history, color: mutedColor),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const HistorialEntregasScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!error && entregas.isNotEmpty && pendientesList.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 40, color: mutedColor),
                      const SizedBox(height: 12),
                      Text(
                        'Ya entregaste todos tus pedidos de hoy',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: mutedColor),
                      ),
                    ],
                  ),
                )
              else
                for (final remision in pendientesList) ...[
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
          );
        },
      ),
    );
  }
}
