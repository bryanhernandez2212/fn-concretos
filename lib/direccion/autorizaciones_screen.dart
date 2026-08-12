import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'comercial_service.dart';
import 'pedido.dart';
import 'pedido_detail_screen.dart';

const _accentYellow = Color(0xFFFFCC00);

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
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return SafeArea(
      child: RefreshIndicator(
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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _accentYellow.withValues(alpha: 0.18)),
                    child: const Icon(Icons.fact_check_outlined, color: _accentYellow),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Autorizaciones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                        Text(
                          snapshot.connectionState == ConnectionState.done && snapshot.hasData
                              ? '${snapshot.data!.length} pendientes de crédito'
                              : 'Pedidos pendientes de autorizar',
                          style: TextStyle(fontSize: 13, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ];

            if (snapshot.connectionState != ConnectionState.done) {
              children.add(const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator())));
            } else if (snapshot.hasError) {
              children.add(_ErrorState(
                message: snapshot.error is AuthException ? (snapshot.error as AuthException).message : 'No se pudo cargar la bandeja',
                onRetry: _refresh,
                cardColor: cardColor,
                borderColor: borderColor,
                mutedColor: mutedColor,
              ));
            } else if (snapshot.data!.isEmpty) {
              children.add(_EmptyState(cardColor: cardColor, borderColor: borderColor, mutedColor: mutedColor));
            } else {
              for (final pedido in snapshot.data!) {
                children.add(_PedidoCard(
                  pedido: pedido,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () async {
                    final refrescar = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (context) => PedidoDetailScreen(pedido: pedido)),
                    );
                    if (refrescar == true) _refresh();
                  },
                ));
                children.add(const SizedBox(height: 12));
              }
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, BottomNavBar.clearance(context) + 16),
              children: children,
            );
          },
        ),
      ),
    );
  }
}

class _PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _PedidoCard({
    required this.pedido,
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(pedido.obraNombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                  ),
                  Text(pedido.folio, style: TextStyle(fontSize: 12, color: mutedColor)),
                ],
              ),
              const SizedBox(height: 4),
              Text(pedido.clienteNombre, style: TextStyle(fontSize: 13, color: mutedColor)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoPill(icon: Icons.water_drop_outlined, text: '${pedido.volumenSolicitadoM3} m³', mutedColor: mutedColor, textColor: textColor),
                  const SizedBox(width: 8),
                  _InfoPill(icon: Icons.payments_outlined, text: pedido.condicionPago, mutedColor: mutedColor, textColor: textColor),
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
      decoration: BoxDecoration(color: mutedColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
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

class _EmptyState extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Color mutedColor;

  const _EmptyState({required this.cardColor, required this.borderColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Icon(Icons.task_alt, color: mutedColor, size: 28),
          const SizedBox(height: 10),
          Text('No hay pedidos pendientes de autorizar', style: TextStyle(fontSize: 13.5, color: mutedColor), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color cardColor;
  final Color borderColor;
  final Color mutedColor;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.cardColor,
    required this.borderColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(fontSize: 13.5, color: mutedColor), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
