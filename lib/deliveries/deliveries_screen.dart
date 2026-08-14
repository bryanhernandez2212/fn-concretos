import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'delivery_detail_screen.dart';
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

/// Delivery summary card shared with `HistorialEntregasScreen` so past-day
/// entregas render identically to today's.
class RemisionCard extends StatelessWidget {
  final Remision remision;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const RemisionCard({
    super.key,
    required this.remision,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      remision.obra,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ),
                  _HitoChip(hito: remision.hitoActual),
                ],
              ),
              const SizedBox(height: 4),
              Text(remision.cliente, style: TextStyle(fontSize: 13, color: mutedColor)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 15, color: mutedColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      remision.direccion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: mutedColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoPill(icon: Icons.access_time, text: remision.horaProgramada, mutedColor: mutedColor, textColor: textColor),
                  const SizedBox(width: 8),
                  _InfoPill(icon: Icons.water_drop_outlined, text: '${remision.volumenM3} m³', mutedColor: mutedColor, textColor: textColor),
                  const SizedBox(width: 8),
                  _InfoPill(icon: Icons.grain, text: remision.tipoConcreto, mutedColor: mutedColor, textColor: textColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color mutedColor;
  final Color textColor;

  const _InfoPill({required this.icon, required this.text, required this.mutedColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: mutedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}

/// Status chip summarizing where a Remisión sits in its 9-step hito chain:
/// muted before it starts moving, brand yellow while in progress, green
/// once fully delivered/signed. A null hito means no Remisión exists yet
/// (still just today's production programming) — shown as a plain
/// "Programado" chip.
class _HitoChip extends StatelessWidget {
  final HitoEntrega? hito;

  const _HitoChip({required this.hito});

  @override
  Widget build(BuildContext context) {
    final hito = this.hito;
    final Color color;
    final String label;
    if (hito == null) {
      color = Colors.grey;
      label = 'Programado';
    } else if (hito == HitoEntrega.entregado) {
      color = const Color(0xFF4CAF50);
      label = hito.label;
    } else if (hito == HitoEntrega.conIncidencia) {
      color = const Color(0xFFEF5350);
      label = hito.label;
    } else if (hito == HitoEntrega.cargandoPlanta) {
      color = Colors.grey;
      label = hito.label;
    } else {
      color = _accentYellow;
      label = hito.label;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
