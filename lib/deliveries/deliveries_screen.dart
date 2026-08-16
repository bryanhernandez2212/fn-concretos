import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'delivery_detail_screen.dart';
import 'deliveries_widgets.dart';
import 'entregas_service.dart';
import 'historial_entregas_screen.dart';
import 'remision.dart';

const _accentYellow = Color(0xFFFFCC00);

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

  @override
  void initState() {
    super.initState();
    _future = EntregasService.entregasDelDia();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return SafeArea(
      child: FutureBuilder<List<Remision>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error is AuthException ? (snapshot.error as AuthException).message : 'No se pudieron cargar tus entregas',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedColor),
                ),
              ),
            );
          }

          final entregas = snapshot.data!;
          final pendientes = entregas.where((r) => r.hitoActual != HitoEntrega.entregado).length;

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, BottomNavBar.clearance(context) + 16),
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
                    child: const Icon(Icons.local_shipping_outlined, color: _accentYellow),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis entregas del día',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
                        ),
                        Text(
                          entregas.isEmpty ? 'No tienes entregas asignadas hoy' : '$pendientes pendientes de ${entregas.length}',
                          style: TextStyle(fontSize: 13, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Historial de entregas',
                    icon: Icon(Icons.history, color: mutedColor),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HistorialEntregasScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              for (final remision in entregas) ...[
                RemisionCard(
                  remision: remision,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => DeliveryDetailScreen(remision: remision)),
                    );
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
