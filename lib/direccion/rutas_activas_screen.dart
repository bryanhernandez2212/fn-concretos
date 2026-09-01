import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/remision_tracking.dart';
import '../theme/app_colors.dart';
import '../widgets/notification_bell_button.dart';
import 'vehicle_marker_icon.dart';

const _accentYellow = AppColors.accent;

/// Cycled across simultaneous routes so overlapping polylines stay visually
/// distinguishable on one shared map (all markers keep the default pin —
/// only [google_navigation_flutter]'s bitmap-registration API can recolor
/// those, which isn't worth the added complexity just for this).
const _routeColors = [
  _accentYellow,
  Color(0xFF4FC3F7),
  Color(0xFFFF7043),
  Color(0xFFAB47BC),
  Color(0xFF66BB6A),
];

/// "Rutas activas" — one map for every remisión currently out of the plant
/// (not just one pedido at a time, unlike `PedidoDetailScreen`'s "Ubicación
/// en vivo" section). Built from `OperacionesService.remisionesEnRuta()`
/// (fleet-wide, real) then polls each remisión's `GET /remisiones/{id}/ruta`
/// every 15s — same cadence as the per-pedido tracking card — to move the
/// markers/trails.
class RutasActivasScreen extends StatefulWidget {
  const RutasActivasScreen({super.key});

  @override
  State<RutasActivasScreen> createState() => _RutasActivasScreenState();
}

class _RutasActivasScreenState extends State<RutasActivasScreen> {
  GoogleMapViewController? _mapController;
  Timer? _timer;

  List<RemisionResumen> _remisiones = const [];
  final Map<int, RutaRemision> _rutas = {};
  bool _cargandoInicial = true;
  String? _errorInicial;

  /// Whether the camera has already been fit to the current batch of trucks
  /// since the map was last (re)built — re-fitting on every 15s poll would
  /// fight the user's own pan/zoom.
  bool _camaraAjustada = false;

  /// Heading per remisión id, degrees clockwise from north, kept across
  /// polls — a poll with fewer than two `historial` points shouldn't snap a
  /// truck's icon back to facing north.
  final Map<int, double> _rotaciones = {};

  /// Live marker/polyline per remisión id, updated in place (`updateMarkers`/
  /// `updatePolylines`) rather than cleared and re-added every poll — that's
  /// what lets [glideMarkerTo] slide a truck smoothly between GPS pings
  /// instead of it snapping to the new position every 15s.
  final Map<int, Marker> _markers = {};
  final Map<int, Polyline> _polylines = {};
  final Map<int, Timer> _glides = {};

  /// Hides the truck list panel so the map fills the whole screen below the
  /// AppBar — the map itself never leaves the widget tree when this toggles
  /// (see `_buildBody`), so the live marker/polyline state isn't lost.
  bool _pantallaCompleta = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final glide in _glides.values) {
      glide.cancel();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final habiaCamiones = _remisiones.isNotEmpty;
    try {
      final remisiones = await OperacionesService.remisionesEnRuta();
      final rutas = <int, RutaRemision>{};
      for (final remision in remisiones) {
        try {
          rutas[remision.id] = await OperacionesService.rutaRemision(
            remision.id,
          );
        } catch (_) {
          // One truck failing to report its ruta shouldn't blank the rest
          // of the map — it just won't have a marker this round.
        }
      }
      if (!mounted) return;
      setState(() {
        _remisiones = remisiones;
        _rutas
          ..clear()
          ..addAll(rutas);
        _cargandoInicial = false;
        _errorInicial = null;
        if (!habiaCamiones && remisiones.isNotEmpty) _camaraAjustada = false;
      });
      await _actualizarMapa();
    } on AuthException catch (e) {
      if (!mounted) return;
      // Only the very first load has nothing to fall back to — a background
      // refresh failing just leaves the last known positions on screen.
      if (_cargandoInicial) setState(() => _errorInicial = e.message);
    }
  }

  Future<void> _actualizarMapa() async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      final posiciones = <LatLng>[];
      final idsVistos = <int>{};

      for (final (index, remision) in _remisiones.indexed) {
        final ruta = _rutas[remision.id];
        final ultima = ruta?.ultimaUbicacion;
        if (ultima == null) continue;
        idsVistos.add(remision.id);
        final color = _routeColors[index % _routeColors.length];
        final posicion = LatLng(
          latitude: ultima.latitud,
          longitude: ultima.longitud,
        );
        posiciones.add(posicion);

        if ((ruta?.historial.length ?? 0) > 1) {
          _rotaciones[remision.id] = bearingBetween(
            ruta!.historial[ruta.historial.length - 2],
            ruta.historial[ruta.historial.length - 1],
          );
        }
        final rotacion = _rotaciones[remision.id] ?? 0;

        final marcadorPrevio = _markers[remision.id];
        if (marcadorPrevio == null) {
          // First sighting of this remisión — nothing to glide from yet, so
          // it just appears at its current position.
          final nuevos = await controller.addMarkers([
            MarkerOptions(
              position: posicion,
              icon: await VehicleMarkerIcon.forColor(color),
              anchor: VehicleMarkerIcon.anchor,
              rotation: rotacion,
              infoWindow: InfoWindow(
                title: remision.folioRemision,
                snippet: [
                  if (remision.conductorId != null)
                    'Conductor #${remision.conductorId}',
                  remision.estatus.replaceAll('_', ' '),
                ].join(' · '),
              ),
            ),
          ]);
          final marcador = nuevos.isNotEmpty ? nuevos.first : null;
          if (marcador != null) _markers[remision.id] = marcador;
        } else {
          _glides[remision.id]?.cancel();
          _glides[remision.id] = glideMarkerTo(
            controller,
            marcadorPrevio,
            toPosition: posicion,
            toRotation: rotacion,
            duration: const Duration(seconds: 15),
            onUpdate: (updated) => _markers[remision.id] = updated,
          );
        }

        if ((ruta?.historial.length ?? 0) > 1) {
          final puntos = ruta!.historial
              .map((p) => LatLng(latitude: p.latitud, longitude: p.longitud))
              .toList();
          final polilineaPrevia = _polylines[remision.id];
          if (polilineaPrevia == null) {
            final nuevas = await controller.addPolylines([
              PolylineOptions(points: puntos, strokeColor: color, strokeWidth: 4),
            ]);
            final polilinea = nuevas.isNotEmpty ? nuevas.first : null;
            if (polilinea != null) _polylines[remision.id] = polilinea;
          } else {
            final actualizadas = await controller.updatePolylines([
              polilineaPrevia.copyWith(
                options: polilineaPrevia.options.copyWith(points: puntos),
              ),
            ]);
            final polilinea = actualizadas.isNotEmpty
                ? actualizadas.first
                : null;
            if (polilinea != null) _polylines[remision.id] = polilinea;
          }
        }
      }

      // Remove overlays for remisiones that dropped off this poll's list
      // (delivered, or otherwise no longer "en ruta").
      final idsAusentes = _markers.keys
          .where((id) => !idsVistos.contains(id))
          .toList();
      for (final id in idsAusentes) {
        _glides.remove(id)?.cancel();
        final marcador = _markers.remove(id);
        if (marcador != null) await controller.removeMarkers([marcador]);
        final polilinea = _polylines.remove(id);
        if (polilinea != null) await controller.removePolylines([polilinea]);
      }

      if (posiciones.isNotEmpty && !_camaraAjustada) {
        _camaraAjustada = true;
        await controller.animateCamera(
          posiciones.length == 1
              ? CameraUpdate.newLatLngZoom(posiciones.first, 14)
              : CameraUpdate.newLatLngBounds(_bounds(posiciones), padding: 60),
        );
      }
    } catch (_) {
      // Best-effort overlay refresh — a transient platform-view hiccup here
      // shouldn't crash the 15s poll loop.
    }
  }

  Future<void> _centrarEnTodas() async {
    final controller = _mapController;
    if (controller == null) return;
    final posiciones = _rutas.values
        .map((r) => r.ultimaUbicacion)
        .whereType<GpsPing>()
        .map((p) => LatLng(latitude: p.latitud, longitude: p.longitud))
        .toList();
    if (posiciones.isEmpty) return;
    await controller.animateCamera(
      posiciones.length == 1
          ? CameraUpdate.newLatLngZoom(posiciones.first, 14)
          : CameraUpdate.newLatLngBounds(_bounds(posiciones), padding: 60),
    );
  }

  Future<void> _centrarEn(int remisionId) async {
    final controller = _mapController;
    final ultima = _rutas[remisionId]?.ultimaUbicacion;
    if (controller == null || ultima == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(latitude: ultima.latitud, longitude: ultima.longitud),
        15,
      ),
    );
  }

  static LatLngBounds _bounds(List<LatLng> puntos) {
    var minLat = puntos.first.latitude, maxLat = puntos.first.latitude;
    var minLng = puntos.first.longitude, maxLng = puntos.first.longitude;
    for (final punto in puntos.skip(1)) {
      if (punto.latitude < minLat) minLat = punto.latitude;
      if (punto.latitude > maxLat) maxLat = punto.latitude;
      if (punto.longitude < minLng) minLng = punto.longitude;
      if (punto.longitude > maxLng) maxLng = punto.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(latitude: minLat, longitude: minLng),
      northeast: LatLng(latitude: maxLat, longitude: maxLng),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas activas'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: NotificationBellButton()),
          if (_remisiones.isNotEmpty)
            IconButton(
              tooltip: _pantallaCompleta
                  ? 'Salir de pantalla completa'
                  : 'Ver en pantalla completa',
              icon: Icon(
                _pantallaCompleta ? Icons.fullscreen_exit : Icons.fullscreen,
              ),
              onPressed: () =>
                  setState(() => _pantallaCompleta = !_pantallaCompleta),
            ),
          IconButton(
            tooltip: 'Ver todas',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: _remisiones.isEmpty ? null : _centrarEnTodas,
          ),
        ],
      ),
      body: _buildBody(isDark, textColor, mutedColor, cardColor, borderColor),
    );
  }

  Widget _buildBody(
    bool isDark,
    Color textColor,
    Color mutedColor,
    Color cardColor,
    Color borderColor,
  ) {
    if (_cargandoInicial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorInicial != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: mutedColor),
              const SizedBox(height: 12),
              Text(
                _errorInicial!,
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor),
              ),
            ],
          ),
        ),
      );
    }
    if (_remisiones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 40, color: mutedColor),
              const SizedBox(height: 12),
              Text(
                'No hay camiones en ruta en este momento',
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor),
              ),
            ],
          ),
        ),
      );
    }

    final primeraUbicacion = _rutas.values
        .map((r) => r.ultimaUbicacion)
        .whereType<GpsPing>()
        .cast<GpsPing?>()
        .firstWhere((_) => true, orElse: () => null);

    // The map is always in the tree, filling the whole body — only the
    // bottom list panel is toggled by [_pantallaCompleta] — so switching in
    // and out of "pantalla completa" never tears down and recreates the
    // native map view (that would lose the camera position and force a
    // fresh `onViewCreated`/marker rebuild).
    return Stack(
      children: [
        Positioned.fill(
          child: primeraUbicacion == null
              ? Center(
                  child: Text(
                    'Esperando la primera señal GPS.',
                    style: TextStyle(fontSize: 13, color: mutedColor),
                  ),
                )
              : GoogleMapsMapView(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      latitude: primeraUbicacion.latitud,
                      longitude: primeraUbicacion.longitud,
                    ),
                    zoom: 12,
                  ),
                  initialMapColorScheme: isDark
                      ? MapColorScheme.dark
                      : MapColorScheme.light,
                  onViewCreated: (controller) {
                    _mapController = controller;
                    _actualizarMapa();
                  },
                ),
        ),
        if (!_pantallaCompleta)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 300,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: _remisiones.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final remision = _remisiones[index];
                      final ruta = _rutas[remision.id];
                      final tieneUbicacion = ruta?.ultimaUbicacion != null;
                      return Material(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: tieneUbicacion
                              ? () => _centrarEn(remision.id)
                              : null,
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
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        _routeColors[index %
                                            _routeColors.length],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        remision.folioRemision,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          remision.estatus.replaceAll('_', ' '),
                                          if (remision.conductorId != null)
                                            'Conductor #${remision.conductorId}',
                                        ].join(' · '),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: mutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!tieneUbicacion)
                                  Text(
                                    'Sin señal',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: mutedColor,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.my_location,
                                    size: 18,
                                    color: mutedColor,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
