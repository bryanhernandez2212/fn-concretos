import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../comercial/comercial_service.dart';
import '../../comercial/pedido.dart';
import '../../direccion/live_tracking/live_tracking_widgets.dart';
import '../../operaciones/operaciones_service.dart';
import '../../operaciones/remision_tracking.dart';
import '../../theme/app_colors.dart';
import '../asesor_comercial_widgets.dart';

/// Estatus in which a remisión has left planta and hasn't been delivered:
/// the ones worth showing on a live map.
const estatusEnRuta = {
  'salio_planta',
  'en_camino',
  'proximo_llegar',
  'con_atraso',
  'en_obra',
  'descargando',
};

bool remisionEnRuta(RemisionResumen r) => estatusEnRuta.contains(r.estatus);

/// Live map of a pedido for its asesor: one map per remisión on the road,
/// reusing Dirección's `LiveTrackingCard` (truck marker gliding between GPS
/// pings, street-level recorrido, ETA and remaining route, polled every 15s
/// from `GET /remisiones/{id}/ruta`). Read-only.
class SeguimientoMapaScreen extends StatefulWidget {
  final Pedido pedido;

  const SeguimientoMapaScreen({super.key, required this.pedido});

  @override
  State<SeguimientoMapaScreen> createState() => _SeguimientoMapaScreenState();
}

class _SeguimientoMapaScreenState extends State<SeguimientoMapaScreen> {
  late Future<List<RemisionResumen>> _remisiones;
  late Future<Obra?> _obra;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _remisiones = OperacionesService.remisionesPorPedido(widget.pedido.id);
    // Best-effort: without the obra there's just no destino/ETA overlay.
    _obra = () async {
      try {
        return await ComercialService.obtenerObra(widget.pedido.obraId);
      } catch (_) {
        return null;
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);

    return Scaffold(
      appBar: AppBar(
        title: Text('Seguimiento · ${widget.pedido.folio}'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_cargar),
        child: FutureBuilder<List<RemisionResumen>>(
          future: _remisiones,
          builder: (context, snapshot) {
            final children = <Widget>[
              Text(
                widget.pedido.clienteNombre,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor),
              ),
              Text(widget.pedido.obraNombre, style: TextStyle(fontSize: 13.5, color: mutedColor)),
              const SizedBox(height: 16),
            ];
            if (snapshot.connectionState != ConnectionState.done) {
              children.add(const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())));
            } else if (snapshot.hasError) {
              children.add(
                ErrorState(
                  message: snapshot.error is AuthException
                      ? (snapshot.error as AuthException).message
                      : 'No se pudo cargar el seguimiento',
                  onRetry: () => setState(_cargar),
                  cardColor: cardColor,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                ),
              );
            } else {
              final enRuta = snapshot.data!.where(remisionEnRuta).toList();
              if (enRuta.isEmpty) {
                children.add(
                  EmptyState(
                    message: 'Ningún camión de este pedido va en ruta ahora mismo.',
                    icon: Icons.local_shipping_outlined,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    mutedColor: mutedColor,
                  ),
                );
              }
              for (final r in enRuta) {
                children.add(
                  LiveTrackingCard(
                    remisionId: r.id,
                    folioRemision: r.folioRemision,
                    conductorId: r.conductorId,
                    volumen: r.volumen,
                    obraFuture: _obra,
                    isDark: isDark,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                );
                children.add(const SizedBox(height: 16));
              }
            }
            return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 32), children: children);
          },
        ),
      ),
    );
  }
}
