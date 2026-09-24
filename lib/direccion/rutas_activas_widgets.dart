import 'package:flutter/material.dart';
import '../operaciones/remision_tracking.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'route_eta.dart';

/// Cycled across simultaneous routes so overlapping polylines stay visually
/// distinguishable on one shared map (all markers keep the default pin —
/// only [google_navigation_flutter]'s bitmap-registration API can recolor
/// those, which isn't worth the added complexity just for this).
const routeColors = [AppColors.accent, Color(0xFF4FC3F7), Color(0xFFFF7043), Color(0xFFAB47BC), Color(0xFF66BB6A)];

/// Route color for the remisión at [index] in the current list — shared by
/// its map marker/polyline and its row in [RutasTruckListPanel].
Color routeColorFor(int index) => routeColors[index % routeColors.length];

/// Centered icon + message, used for `RutasActivasScreen`'s initial error
/// and "no hay camiones en ruta" states.
class RutasMessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color mutedColor;

  const RutasMessageState({super.key, required this.icon, required this.message, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: mutedColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom panel listing every truck en ruta, overlaid on the map — the
/// piece `RutasActivasScreen`'s "pantalla completa" toggle hides. Pure
/// presentation: all polling/ETA state stays in the screen and is handed in
/// as plain maps keyed by remisión id.
class RutasTruckListPanel extends StatelessWidget {
  final List<RemisionResumen> remisiones;
  final Map<int, RutaRemision> rutas;
  final Map<int, double> velocidades;
  final Map<int, RouteEtaTracker> etaTrackers;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onCentrarEn;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const RutasTruckListPanel({
    super.key,
    required this.remisiones,
    required this.rutas,
    required this.velocidades,
    required this.etaTrackers,
    required this.onRefresh,
    required this.onCentrarEn,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            // The floating BottomNavBar overlays the bottom of this
            // panel (see DireccionHomeScreen's shared shell) — without
            // this, the last remisión ends up scrolled only as far as
            // the plain 24px padding, which sits right under the nav
            // bar's pill instead of clear of it.
            padding: EdgeInsets.fromLTRB(20, 16, 20, BottomNavBar.clearance(context) + 16),
            itemCount: remisiones.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final remision = remisiones[index];
              final tieneUbicacion = rutas[remision.id]?.ultimaUbicacion != null;
              final eta = etaTrackers[remision.id];
              return RutaTruckRow(
                remision: remision,
                color: routeColorFor(index),
                tieneUbicacion: tieneUbicacion,
                velocidad: velocidades[remision.id],
                duracionRestanteSegundos: eta?.duracionRestanteSegundos,
                progreso: eta?.progreso,
                onTap: tieneUbicacion ? () => onCentrarEn(remision.id) : null,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One truck's row in [RutasTruckListPanel]: route-color dot, folio,
/// estatus/conductor, optional "X km/h · Llega en Y min" line and route
/// progress bar, plus a "Sin señal"/locate indicator.
class RutaTruckRow extends StatelessWidget {
  final RemisionResumen remision;
  final Color color;
  final bool tieneUbicacion;
  final double? velocidad;
  final int? duracionRestanteSegundos;
  final double? progreso;
  final VoidCallback? onTap;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const RutaTruckRow({
    super.key,
    required this.remision,
    required this.color,
    required this.tieneUbicacion,
    required this.velocidad,
    required this.duracionRestanteSegundos,
    required this.progreso,
    required this.onTap,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remision.folioRemision,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        remision.estatus.replaceAll('_', ' '),
                        if (remision.conductorId != null) 'Conductor #${remision.conductorId}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12.5, color: mutedColor),
                    ),
                    if (velocidad != null || duracionRestanteSegundos != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (velocidad != null) '${velocidad!.round()} km/h',
                          if (duracionRestanteSegundos != null) 'Llega en ${formatEta(duracionRestanteSegundos!)}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                      ),
                    ],
                    if (progreso != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progreso,
                          minHeight: 4,
                          backgroundColor: borderColor,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!tieneUbicacion)
                Text('Sin señal', style: TextStyle(fontSize: 11.5, color: mutedColor))
              else
                Icon(Icons.my_location, size: 18, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}
