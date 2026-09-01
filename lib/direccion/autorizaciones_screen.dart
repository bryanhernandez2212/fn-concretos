import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/notification_bell_button.dart';
import 'autorizaciones_widgets.dart';
import 'comercial_service.dart';
import 'pedido.dart';
import 'pedido_detail_screen.dart';

const _accentYellow = AppColors.accent;

/// "Bandeja de pedidos pendientes de autorizar" — Dirección's main tab:
/// every Pedido whose estatusGeneral is `pendiente_autorizacion_pago`,
/// fetched live from the `comercial` service.
class AutorizacionesScreen extends StatefulWidget {
  const AutorizacionesScreen({super.key});

  @override
  State<AutorizacionesScreen> createState() => _AutorizacionesScreenState();
}

class _AutorizacionesScreenState extends State<AutorizacionesScreen> {
  late Future<List<Pedido>> _future;

  @override
  void initState() {
    super.initState();
    _future = ComercialService.pedidosPendientesDePago();
  }

  void _refresh() {
    setState(() {
      _future = ComercialService.pedidosPendientesDePago();
    });
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
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<Pedido>>(
        future: _future,
        builder: (context, snapshot) {
          final children = <Widget>[
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
                    Icons.fact_check_outlined,
                    color: _accentYellow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Autorizaciones',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        snapshot.connectionState == ConnectionState.done &&
                                snapshot.hasData
                            ? '${snapshot.data!.length} pendientes de crédito'
                            : 'Pedidos pendientes de autorizar',
                        style: TextStyle(fontSize: 13, color: mutedColor),
                      ),
                    ],
                  ),
                ),
                const NotificationBellButton(),
              ],
            ),
            const SizedBox(height: 24),
          ];

          if (snapshot.connectionState != ConnectionState.done) {
            children.add(
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          } else if (snapshot.hasError) {
            // TEMP debug: surface the real exception, since the fallback
            // message below only fires for non-AuthException errors.
            debugPrint(
              'AutorizacionesScreen error: ${snapshot.error.runtimeType}: ${snapshot.error}',
            );
            children.add(
              ErrorState(
                message: snapshot.error is AuthException
                    ? (snapshot.error as AuthException).message
                    : 'No se pudo cargar la bandeja',
                onRetry: _refresh,
                cardColor: cardColor,
                borderColor: borderColor,
                mutedColor: mutedColor,
              ),
            );
          } else if (snapshot.data!.isEmpty) {
            children.add(
              EmptyState(
                cardColor: cardColor,
                borderColor: borderColor,
                mutedColor: mutedColor,
              ),
            );
          } else {
            for (final pedido in snapshot.data!) {
              children.add(
                PedidoCard(
                  pedido: pedido,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () async {
                    final refrescar = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) =>
                            PedidoDetailScreen(pedido: pedido),
                      ),
                    );
                    if (refrescar == true) _refresh();
                  },
                ),
              );
              children.add(const SizedBox(height: 12));
            }
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              BottomNavBar.clearance(context) + 16,
            ),
            children: children,
          );
        },
      ),
    );
  }
}
