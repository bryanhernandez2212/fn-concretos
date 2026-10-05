import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../finanzas/finanzas_service.dart';
import '../../finanzas/orden_compra.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/notification_bell_button.dart';
import 'orden_compra_detail_screen.dart';
import 'ordenes_compra_widgets.dart';

const _accentYellow = AppColors.accent;

/// Dirección's "Compras" tab: órdenes de compra waiting on authorization
/// (`finanzas-service`'s `GET /ordenes-compra`, narrowed client-side by
/// [OrdenCompra.porAutorizar]). Same shape as `AutorizacionesScreen` for
/// credit — list → detail → autorizar/rechazar → pop back and refresh.
class OrdenesCompraScreen extends StatefulWidget {
  const OrdenesCompraScreen({super.key});

  @override
  State<OrdenesCompraScreen> createState() => _OrdenesCompraScreenState();
}

class _OrdenesCompraScreenState extends State<OrdenesCompraScreen> {
  late Future<List<OrdenCompra>> _future = _cargar();

  Future<List<OrdenCompra>> _cargar() async {
    final ordenes = await FinanzasService.ordenesCompra();
    return ordenes.where((o) => o.porAutorizar).toList()..sort(
      (a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
    );
  }

  void _refresh() => setState(() => _future = _cargar());

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<OrdenCompra>>(
        future: _future,
        builder: (context, snapshot) {
          final listo =
              snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData;
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
                    Icons.shopping_cart_outlined,
                    color: _accentYellow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Órdenes de compra',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        listo
                            ? '${snapshot.data!.length} por autorizar'
                            : 'Órdenes pendientes de autorizar',
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
            children.add(
              OrdenesCompraMensaje(
                icon: Icons.error_outline,
                iconColor: Colors.redAccent,
                mensaje: snapshot.error is AuthException
                    ? (snapshot.error as AuthException).message
                    : 'No se pudieron cargar las órdenes de compra',
                onRetry: _refresh,
              ),
            );
          } else if (snapshot.data!.isEmpty) {
            children.add(
              const OrdenesCompraMensaje(
                icon: Icons.task_alt,
                mensaje: 'No hay órdenes de compra pendientes de autorizar',
              ),
            );
          } else {
            for (final orden in snapshot.data!) {
              children.add(
                OrdenCompraCard(
                  orden: orden,
                  onTap: () async {
                    final refrescar = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) =>
                            OrdenCompraDetailScreen(ordenId: orden.id),
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
