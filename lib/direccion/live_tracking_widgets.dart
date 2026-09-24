import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/remision_tracking.dart';
import '../theme/app_colors.dart';
import 'live_tracking_fullscreen_screen.dart';
import 'pedido.dart';
import 'pedido_detail_widgets.dart' show PlaceholderCard;
import 'route_eta.dart';
import 'vehicle_marker_icon.dart';

const _accentYellow = AppColors.accent;

/// Loads the pedido's remisiones and shows one [LiveTrackingCard] per
/// remisión found (a pedido can have both an olla and a bomba remisión, per
/// `AsignacionOllaBomba`). Kept in its own `FutureBuilder`, separate from
/// the screen's main future, so a tracking failure never blocks the rest of
/// the pedido detail from loading.
class LiveTrackingSection extends StatelessWidget {
  final Future<List<RemisionResumen>> remisionesFuture;

  /// The pedido's obra — best-effort, may resolve to `null` (failed lookup)
  /// without this section failing; it just means no ETA/progress bar on the
  /// tracking cards below, same "best-effort, degrade gracefully" reasoning
  /// as `remisionesFuture` having its own error path.
  final Future<Obra?> obraFuture;

  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const LiveTrackingSection({
    super.key,
    required this.remisionesFuture,
    required this.obraFuture,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RemisionResumen>>(
      future: remisionesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final remisiones = snapshot.hasError
            ? const <RemisionResumen>[]
            : snapshot.data!;
        if (remisiones.isEmpty) {
          return PlaceholderCard(
            text: snapshot.hasError
                ? (snapshot.error is AuthException
                      ? (snapshot.error as AuthException).message
                      : 'No se pudo cargar la remisión')
                : 'Aún no hay una remisión generada para este pedido.',
            cardColor: cardColor,
            borderColor: borderColor,
            mutedColor: mutedColor,
          );
        }

        return Column(
          children: [
            for (final remision in remisiones) ...[
              LiveTrackingCard(
                remisionId: remision.id,
                folioRemision: remision.folioRemision,
                conductorId: remision.conductorId,
                volumen: remision.metrosCargados ?? remision.metrosSolicitados,
                obraFuture: obraFuture,
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              if (remision != remisiones.last) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

/// One remisión's live map: current position (marker) plus its recorrido
/// (polyline), refreshed every 15s via `GET /remisiones/{id}/ruta` until the
/// remisión reaches a terminal estatus.
class LiveTrackingCard extends StatefulWidget {
  final int remisionId;
  final String folioRemision;

  /// The driver assigned to this specific remisión — a pedido can be split
  /// across several (e.g. 40 m³ as 4 trucks of 10 m³ each), so Dirección
  /// needs to see which conductor carries which remisión, not just one
  /// combined pedido total. No employee-name lookup exists in this app yet,
  /// so this shows the raw id rather than fabricating a name.
  final int? conductorId;

  /// This remisión's own volume (`metrosCargados` once loaded, else
  /// `metrosSolicitados`) — not the pedido's total.
  final double? volumen;

  /// Best-effort — see `LiveTrackingSection.obraFuture`. Feeds the ETA/
  /// progress overlay's destino; `null` just means that overlay never
  /// appears for this card.
  final Future<Obra?> obraFuture;

  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const LiveTrackingCard({
    super.key,
    required this.remisionId,
    required this.folioRemision,
    required this.conductorId,
    required this.volumen,
    required this.obraFuture,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  State<LiveTrackingCard> createState() => _LiveTrackingCardState();
}

class _LiveTrackingCardState extends State<LiveTrackingCard> {
  static const _terminales = {'entregado', 'con_incidencia'};

  RutaRemision? _ruta;
  String? _errorText;
  GoogleMapViewController? _mapController;
  Timer? _timer;

  /// Heading for the marker icon, degrees clockwise from north. Kept across
  /// polls rather than recomputed from scratch each time, since a poll with
  /// fewer than two `historial` points (e.g. right after the truck stops
  /// briefly) shouldn't snap the icon back to facing north.
  double _rotation = 0;

  /// Live marker/polyline, updated in place (`updateMarkers`/
  /// `updatePolylines`) rather than cleared and re-added every poll — that's
  /// what lets [glideMarkerTo] slide the truck smoothly between GPS pings
  /// instead of it snapping to the new position every 15s.
  Marker? _marker;
  Polyline? _polyline;
  Timer? _glide;

  LatLng? _destino;
  RouteEtaTracker? _eta;
  double? _velocidadKmh;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
    widget.obraFuture.then((obra) {
      if (!mounted || obra == null) return;
      _destino = LatLng(latitude: obra.latitud, longitude: obra.longitud);
      _eta = RouteEtaTracker(destino: _destino!);
      final ultima = _ruta?.ultimaUbicacion;
      if (ultima != null) _actualizarEta(LatLng(latitude: ultima.latitud, longitude: ultima.longitud));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glide?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ruta = await OperacionesService.rutaRemision(widget.remisionId);
      if (!mounted) return;
      setState(() {
        _ruta = ruta;
        _errorText = null;
      });
      await _updateMapOverlays(ruta);
      if (_terminales.contains(ruta.estatus)) _timer?.cancel();
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    }
  }

  /// Throttled inside [RouteEtaTracker] itself (real routing calls are
  /// billed), so this can be fired on every 15s poll without worrying about
  /// over-calling Directions API — most calls here are no-ops.
  Future<void> _actualizarEta(LatLng posicionActual) async {
    final eta = _eta;
    if (eta == null) return;
    final actualizado = await eta.actualizar(posicionActual);
    if (actualizado && mounted) setState(() {});
  }

  Future<void> _updateMapOverlays(RutaRemision ruta) async {
    final controller = _mapController;
    final ultima = ruta.ultimaUbicacion;
    if (controller == null || ultima == null) return;

    final posicion = LatLng(
      latitude: ultima.latitud,
      longitude: ultima.longitud,
    );
    if (ruta.historial.length > 1) {
      _rotation = bearingBetween(
        ruta.historial[ruta.historial.length - 2],
        ruta.historial[ruta.historial.length - 1],
      );
      _velocidadKmh = speedKmhBetween(
        ruta.historial[ruta.historial.length - 2],
        ruta.historial[ruta.historial.length - 1],
      );
    }
    unawaited(_actualizarEta(posicion));

    final marcadorPrevio = _marker;
    if (marcadorPrevio == null) {
      final nuevos = await controller.addMarkers([
        MarkerOptions(
          position: posicion,
          icon: await VehicleMarkerIcon.forColor(_accentYellow),
          anchor: VehicleMarkerIcon.anchor,
          rotation: _rotation,
        ),
      ]);
      if (nuevos.isNotEmpty && nuevos.first != null) _marker = nuevos.first;
    } else {
      _glide?.cancel();
      _glide = glideMarkerTo(
        controller,
        marcadorPrevio,
        toPosition: posicion,
        toRotation: _rotation,
        duration: const Duration(seconds: 15),
        onUpdate: (updated) => _marker = updated,
      );
    }

    if (ruta.historial.length > 1) {
      final puntos = ruta.historial
          .map((p) => LatLng(latitude: p.latitud, longitude: p.longitud))
          .toList();
      final polilineaPrevia = _polyline;
      if (polilineaPrevia == null) {
        final nuevas = await controller.addPolylines([
          PolylineOptions(points: puntos, strokeColor: _accentYellow),
        ]);
        if (nuevas.isNotEmpty && nuevas.first != null) {
          _polyline = nuevas.first;
        }
      } else {
        final actualizadas = await controller.updatePolylines([
          polilineaPrevia.copyWith(
            options: polilineaPrevia.options.copyWith(points: puntos),
          ),
        ]);
        if (actualizadas.isNotEmpty && actualizadas.first != null) {
          _polyline = actualizadas.first;
        }
      }
    }

    // Recenters every poll — this preview has its own gestures disabled (see
    // the `GoogleMapsMapView` below), so there's no user pan/zoom for this
    // to fight, unlike `RutasActivasScreen`'s fully-interactive map.
    await controller.animateCamera(CameraUpdate.newLatLng(posicion));
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _ruta;

    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 18,
                      color: widget.mutedColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.folioRemision,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.textColor,
                        ),
                      ),
                    ),
                    if (ruta != null)
                      Text(
                        ruta.estatus,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: widget.mutedColor,
                        ),
                      ),
                    if (ruta?.ultimaUbicacion != null)
                      IconButton(
                        tooltip: 'Ver en pantalla completa',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.fullscreen, color: widget.mutedColor),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveTrackingFullscreenScreen(
                                remisionId: widget.remisionId,
                                folioRemision: widget.folioRemision,
                                conductorId: widget.conductorId,
                                volumen: widget.volumen,
                                obraFuture: widget.obraFuture,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                if (widget.conductorId != null || widget.volumen != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      [
                        if (widget.conductorId != null)
                          'Conductor #${widget.conductorId}',
                        if (widget.volumen != null) '${widget.volumen} m³',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: widget.mutedColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_errorText != null && ruta == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                _errorText!,
                style: TextStyle(fontSize: 13, color: widget.mutedColor),
              ),
            )
          else if (ruta == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (ruta.ultimaUbicacion == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Esperando la primera señal GPS de este viaje.',
                style: TextStyle(fontSize: 13, color: widget.mutedColor),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GoogleMapsMapView(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          latitude: ruta.ultimaUbicacion!.latitud,
                          longitude: ruta.ultimaUbicacion!.longitud,
                        ),
                        zoom: 15,
                      ),
                      initialMapColorScheme: widget.isDark
                          ? MapColorScheme.dark
                          : MapColorScheme.light,
                      // Read-only preview embedded in a scrolling ListView —
                      // a map that captures pan/zoom gestures fights the
                      // list's own vertical scroll for the gesture arena,
                      // causing a visible wobble whenever the drag direction
                      // reverses. It's just a live-position glance, not
                      // something meant to be explored in place, so its own
                      // gestures are disabled entirely.
                      initialScrollGesturesEnabled: false,
                      initialZoomGesturesEnabled: false,
                      initialRotateGesturesEnabled: false,
                      initialTiltGesturesEnabled: false,
                      onViewCreated: (controller) {
                        _mapController = controller;
                        _updateMapOverlays(ruta);
                      },
                    ),
                  ),
                  if (_eta?.progreso != null)
                    Positioned(top: 10, bottom: 10, right: 10, child: RouteProgressBar(progreso: _eta!.progreso!)),
                  if (_velocidadKmh != null || _eta?.duracionRestanteSegundos != null)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: SpeedEtaPill(velocidadKmh: _velocidadKmh, duracionRestanteSegundos: _eta?.duracionRestanteSegundos),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Vertical route-progress bar overlaid on the right edge of a live-tracking
/// map, DiDi-style — fills bottom-up as `progreso` (0.0-1.0, from
/// `RouteEtaTracker`) grows. Purely a progress indicator, not a scrollbar or
/// anything interactive.
class RouteProgressBar extends StatelessWidget {
  final double progreso;

  const RouteProgressBar({super.key, required this.progreso});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: progreso.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(color: _accentYellow, borderRadius: BorderRadius.circular(3)),
          ),
        ),
      ),
    );
  }
}

/// Bottom-left "45 km/h · Llega en 12 min" pill overlaid on a live-tracking
/// map. Renders nothing (`SizedBox.shrink`) if both values are still
/// unknown, so callers can place it unconditionally without an extra null
/// check at the call site.
class SpeedEtaPill extends StatelessWidget {
  final double? velocidadKmh;
  final int? duracionRestanteSegundos;

  const SpeedEtaPill({super.key, required this.velocidadKmh, required this.duracionRestanteSegundos});

  @override
  Widget build(BuildContext context) {
    final velocidad = velocidadKmh;
    final duracion = duracionRestanteSegundos;
    if (velocidad == null && duracion == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (velocidad != null) ...[
            const Icon(Icons.speed, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              '${velocidad.round()} km/h',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
          if (velocidad != null && duracion != null) const SizedBox(width: 10),
          if (duracion != null) ...[
            const Icon(Icons.schedule, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'Llega en ${formatEta(duracion)}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}
