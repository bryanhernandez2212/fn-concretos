import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import 'delivery_detail_screen.dart';
import 'deliveries_widgets.dart' show RemisionCard;
import 'entregas_service.dart';
import 'remision.dart';

/// Full list behind `DeliveriesScreen`'s "Ver todas" button — every Remisión
/// assigned to this conductor today, regardless of hito (unlike the
/// dashboard's "Rutas prioritarias" preview, which only shows the top 3
/// still-pending ones). Fetches its own copy via `EntregasService`, same as
/// `HistorialEntregasScreen` does for a past date, rather than trusting a
/// snapshot handed down from `DeliveriesScreen` that could already be stale
/// by the time this screen is reached.
class TodasLasRutasScreen extends StatefulWidget {
  const TodasLasRutasScreen({super.key});

  @override
  State<TodasLasRutasScreen> createState() => _TodasLasRutasScreenState();
}

class _TodasLasRutasScreenState extends State<TodasLasRutasScreen> {
  late Future<List<Remision>> _future;
  List<Remision>? _ultimaData;

  @override
  void initState() {
    super.initState();
    _future = EntregasService.entregasDelDia();
  }

  Future<void> _refrescar() async {
    final future = EntregasService.entregasDelDia();
    setState(() => _future = future);
    try {
      await future;
    } catch (e) {
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
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.08);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todas mis rutas de hoy'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder<List<Remision>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              _ultimaData = snapshot.data;
            }
            final tieneCache = _ultimaData != null;
            final loading = snapshot.connectionState != ConnectionState.done && !tieneCache;
            final error = !loading && !tieneCache && snapshot.hasError;
            final rutas = _ultimaData ?? const <Remision>[];

            if (loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (error) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 40, color: mutedColor),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.error is AuthException
                              ? (snapshot.error as AuthException).message
                              : 'No se pudieron cargar tus rutas',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            if (rutas.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 40, color: mutedColor),
                        const SizedBox(height: 12),
                        Text(
                          'No tienes rutas asignadas hoy',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                for (final remision in rutas) ...[
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
                              builder: (context) => DeliveryDetailScreen(remision: remision),
                            ),
                          )
                          .then((_) => _refrescar());
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
