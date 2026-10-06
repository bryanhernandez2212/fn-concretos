import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../../auth/auth_service.dart';
import '../../deliveries/listado/deliveries_widgets.dart';
import '../../deliveries/entregas_service.dart';
import '../../operaciones/operaciones_service.dart';
import '../../operaciones/rastreo_gps.dart';
import '../../operaciones/remision_tracking.dart';
import '../../widgets/notification_bell_button.dart';
import '../../comercial/comercial_service.dart';
import '../live_tracking/route_eta.dart';
import '../live_tracking/destino_marker_icon.dart';
import '../live_tracking/recorrido_por_calles.dart';
import '../live_tracking/route_polyline.dart';
import 'rutas_activas_widgets.dart';
import '../live_tracking/vehicle_marker_icon.dart';

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

  /// Fleet-wide asignadas/en ruta/entregadas/pendientes for today, shown as
  /// a summary card above the map — Dirección's equivalent of the
  /// conductor-facing `RutasResumenCard` on `DeliveriesScreen`, but
  /// aggregated across every conductor instead of just the logged-in one.
  /// Refreshed on its own slower timer (below), separate from [_timer]'s
  /// 15s GPS poll, since it costs one call per pedido programado hoy rather
  /// than the cheap unfiltered `/remisiones` the map itself polls.
  ResumenEntregasDia? _resumen;
  Timer? _resumenTimer;

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
  final Map<int, RutaRestantePolyline> _rutasRestantes = {};
  final Map<int, RecorridoPorCalles> _recorridos = {};
  final Map<int, Marker> _marcadoresDestino = {};
  final Set<int> _agregandoDestino = {};

  /// Destino (obra lat/lng) and ETA tracker per remisión id, resolved once
  /// each (not on every 15s poll) via `pedidoId` → `obtenerPedido` →
  /// `obtenerObra` — `RemisionResumen` doesn't come with a destino already
  /// attached the way `deliveries/remision.dart`'s driver-facing model does.
  /// `_resolviendoDestino` guards against kicking off that two-call chain
  /// again for a remisión whose resolve is already in flight.
  final Map<int, LatLng> _destinos = {};
  final Map<int, RouteEtaTracker> _etaTrackers = {};
  final Map<int, double> _velocidades = {};
  final Set<int> _resolviendoDestino = {};

  /// Which medium tracks each vehículo (by vehículo id), for the
  /// "GPS móvil"/"Samsara" chip on each truck row. Resolved from one
  /// fleet-wide `vehiculos()` call rather than one lookup per remisión, and
  /// only re-fetched when a remisión shows up with a vehículo not seen yet —
  /// `origenGps` is a per-unit setting that rarely changes mid-route.
  final Map<int, OrigenGps> _origenesVehiculo = {};
  bool _resolviendoOrigenes = false;

  /// Hides the truck list panel so the map fills the whole screen below the
  /// AppBar — the map itself never leaves the widget tree when this toggles
  /// (see `_buildBody`), so the live marker/polyline state isn't lost.
  bool _pantallaCompleta = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _cargar());
    _cargarResumen();
    _resumenTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _cargarResumen(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resumenTimer?.cancel();
    for (final glide in _glides.values) {
      glide.cancel();
    }
    super.dispose();
  }

  Future<void> _cargarResumen() async {
    try {
      final resumen = await EntregasService.resumenFlotaDelDia();
      if (!mounted) return;
      setState(() => _resumen = resumen);
    } catch (_) {
      // Best-effort, same as the map's own polling below — a failed refresh
      // just leaves the last known counts (or nothing, on the very first
      // load) rather than surfacing an error over the map.
    }
  }

  Future<void> _cargar() async {
    final habiaCamiones = _remisiones.isNotEmpty;
    try {
      final remisiones = await OperacionesService.remisionesEnRuta();
      // Every truck's ruta in parallel, since this re-runs on each poll.
      final rutas = <int, RutaRemision>{};
      await Future.wait(remisiones.map((remision) async {
        try {
          rutas[remision.id] = await OperacionesService.rutaRemision(
            remision.id,
          );
        } catch (_) {
          // One truck failing to report its ruta shouldn't blank the rest
          // of the map — it just won't have a marker this round.
        }
      }));
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
      unawaited(_resolverOrigenes());
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

      // Street-following trails for every truck at once (throttled inside
      // `RecorridoPorCalles`, so most polls make no request).
      await Future.wait([
        for (final remision in _remisiones)
          if (_rutas[remision.id] case final ruta? when ruta.historial.length > 1)
            _recorridos.putIfAbsent(remision.id, RecorridoPorCalles.new).actualizar(ruta.historial),
      ]);

      for (final (index, remision) in _remisiones.indexed) {
        final ruta = _rutas[remision.id];
        final ultima = ruta?.ultimaUbicacion;
        if (ultima == null) continue;
        idsVistos.add(remision.id);
        final color = routeColorFor(index);
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
          final velocidad = speedKmhBetween(
            ruta.historial[ruta.historial.length - 2],
            ruta.historial[ruta.historial.length - 1],
          );
          if (velocidad != null) _velocidades[remision.id] = velocidad;
        }
        final rotacion = _rotaciones[remision.id] ?? 0;

        if (!_destinos.containsKey(remision.id) &&
            !_resolviendoDestino.contains(remision.id)) {
          unawaited(_resolverDestino(remision));
        }
        final tracker = _etaTrackers[remision.id];
        if (tracker != null) {
          unawaited(
            tracker.actualizar(posicion).then((actualizado) async {
              if (!actualizado || !mounted) return;
              setState(() {});
              await _dibujarRutaRestante(remision.id, ruta!.estatus, posicion, color);
            }),
          );
        }

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
          final puntos = _recorridos.putIfAbsent(remision.id, RecorridoPorCalles.new).puntosParaDibujar(ruta!.historial);
          final polilineaPrevia = _polylines[remision.id];
          if (polilineaPrevia == null) {
            final nuevas = await controller.addPolylines([
              PolylineOptions(
                points: puntos,
                strokeColor: color,
                strokeWidth: 4,
              ),
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

        await _dibujarRutaRestante(remision.id, ruta!.estatus, posicion, color);
        await _asegurarMarcadorDestino(remision, color);
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
        await _rutasRestantes.remove(id)?.quitar(controller);
        _recorridos.remove(id);
        final destino = _marcadoresDestino.remove(id);
        if (destino != null) await controller.removeMarkers([destino]);
        _destinos.remove(id);
        _etaTrackers.remove(id);
        _velocidades.remove(id);
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

  /// Adds [remision]'s llegada pin at its obra once the destino has
  /// resolved, in the same color as its truck and route.
  Future<void> _asegurarMarcadorDestino(RemisionResumen remision, Color color) async {
    final controller = _mapController;
    final destino = _destinos[remision.id];
    if (controller == null || destino == null || !tieneCoordenadas(destino)) return;
    if (_marcadoresDestino.containsKey(remision.id) || !_agregandoDestino.add(remision.id)) return;
    try {
      final nuevos = await controller.addMarkers([
        MarkerOptions(
          position: destino,
          icon: await DestinoMarkerIcon.forColor(color),
          anchor: DestinoMarkerIcon.anchor,
          infoWindow: InfoWindow(title: 'Llegada', snippet: remision.folioRemision),
        ),
      ]);
      final marcador = nuevos.isNotEmpty ? nuevos.first : null;
      if (marcador != null) _marcadoresDestino[remision.id] = marcador;
    } finally {
      _agregandoDestino.remove(remision.id);
    }
  }

  /// Road route still ahead for one truck — see `RutaRestantePolyline`.
  /// Only while it's heading to the obra, and only once its destino (and so
  /// its tracker) has resolved.
  Future<void> _dibujarRutaRestante(int remisionId, String estatus, LatLng posicion, Color color) async {
    final controller = _mapController;
    if (controller == null) return;
    final tracker = _etaTrackers[remisionId];
    if (tracker == null || !vaHaciaObra(estatus)) {
      await _rutasRestantes[remisionId]?.quitar(controller);
      return;
    }
    final linea = _rutasRestantes.putIfAbsent(remisionId, RutaRestantePolyline.new);
    await linea.actualizar(controller, tracker.rutaRestanteDesde(posicion), color);
  }

  /// Resolves [remision]'s destino (obra lat/lng) once via `pedidoId` →
  /// `obtenerPedido` → `obtenerObra`, then creates its `RouteEtaTracker`.
  /// Guarded by `_resolviendoDestino` at the call site so this doesn't fire
  /// again every poll while a previous resolve is still in flight; a failed
  /// or missing `pedidoId` just means that truck's row never gets an ETA.
  Future<void> _resolverDestino(RemisionResumen remision) async {
    final pedidoId = remision.pedidoId;
    if (pedidoId == null) {
      debugPrint('[rastreo] remisión ${remision.id} sin pedidoId, no hay destino');
      return;
    }
    _resolviendoDestino.add(remision.id);
    try {
      final pedido = await ComercialService.obtenerPedido(pedidoId);
      final obra = await ComercialService.obtenerObra(pedido.obraId);
      if (!mounted) return;
      final destino = LatLng(latitude: obra.latitud, longitude: obra.longitud);
      debugPrint('[rastreo] remisión ${remision.id} → obra ${obra.id} (${obra.nombre}) en ${obra.latitud},${obra.longitud}');
      _destinos[remision.id] = destino;
      _etaTrackers[remision.id] = RouteEtaTracker(destino: destino);
    } catch (e) {
      // Best-effort — see doc comment above.
      debugPrint('[rastreo] remisión ${remision.id}: no se pudo resolver el destino: $e');
    } finally {
      _resolviendoDestino.remove(remision.id);
    }
  }

  /// The unit whose positions draw this remisión's marker — the olla when
  /// there is one, else the bomba. Null when the remisión has no vehículo
  /// assigned, in which case its row simply shows no origen chip.
  static int? _vehiculoDe(RemisionResumen remision) =>
      remision.vehiculoOllaId ?? remision.vehiculoBombaId;

  Future<void> _resolverOrigenes() async {
    if (_resolviendoOrigenes) return;
    final faltantes = _remisiones
        .map(_vehiculoDe)
        .whereType<int>()
        .where((id) => !_origenesVehiculo.containsKey(id));
    if (faltantes.isEmpty) return;
    _resolviendoOrigenes = true;
    try {
      final vehiculos = await OperacionesService.vehiculos();
      if (!mounted) return;
      setState(() {
        for (final vehiculo in vehiculos) {
          _origenesVehiculo[vehiculo.id] = OrigenGpsInfo.parse(
            vehiculo.origenGps,
          );
        }
      });
    } catch (_) {
      // Best-effort — a failed lookup just leaves the chip off until the
      // next 15s poll tries again.
    } finally {
      _resolviendoOrigenes = false;
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: NotificationBellButton(),
          ),
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
      body: Column(
        children: [
          // Hidden in pantalla completa along with the bottom truck-list
          // panel (see `_buildBody`) so the map gets the full screen.
          if (!_pantallaCompleta && _resumen != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: RutasResumenCard(
                asignadas: _resumen!.asignadas,
                enRuta: _resumen!.enRuta,
                entregadas: _resumen!.entregadas,
                pendientes: _resumen!.pendientes,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
            ),
          Expanded(
            child: _buildBody(
              isDark,
              textColor,
              mutedColor,
              cardColor,
              borderColor,
            ),
          ),
        ],
      ),
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
      return RutasMessageState(
        icon: Icons.error_outline,
        message: _errorInicial!,
        mutedColor: mutedColor,
      );
    }
    if (_remisiones.isEmpty) {
      return RutasMessageState(
        icon: Icons.map_outlined,
        message: 'No hay camiones en ruta en este momento',
        mutedColor: mutedColor,
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
            child: RutasTruckListPanel(
              remisiones: _remisiones,
              rutas: _rutas,
              velocidades: _velocidades,
              etaTrackers: _etaTrackers,
              origenes: {
                for (final remision in _remisiones)
                  remision.id: ?_origenesVehiculo[_vehiculoDe(remision)],
              },
              onRefresh: _cargar,
              onCentrarEn: _centrarEn,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ),
      ],
    );
  }
}
