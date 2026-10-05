import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../../auth/auth_service.dart';
import '../../operaciones/operaciones_service.dart';
import '../../operaciones/remision_tracking.dart';
import '../../theme/app_colors.dart';
import 'live_tracking_widgets.dart' show RouteProgressBar, SpeedEtaPill;
import '../../comercial/pedido.dart';
import 'route_eta.dart';
import 'destino_marker_icon.dart';
import 'recorrido_por_calles.dart';
import 'route_polyline.dart';
import 'vehicle_marker_icon.dart';

const _accentYellow = AppColors.accent;

/// Full-screen, fully interactive version of one [LiveTrackingCard]'s map —
/// opened via its "Ver en pantalla completa" button. Runs its own poll/marker
/// logic rather than sharing `_LiveTrackingCardState`'s: the embedded card's
/// `GoogleMapsMapView` is a distinct native platform view from this one, so
/// each needs its own `GoogleMapViewController` and overlay updates anyway.
class LiveTrackingFullscreenScreen extends StatefulWidget {
  final int remisionId;
  final String folioRemision;
  final int? conductorId;
  final double? volumen;

  /// Best-effort — see `LiveTrackingSection.obraFuture`.
  final Future<Obra?> obraFuture;

  const LiveTrackingFullscreenScreen({
    super.key,
    required this.remisionId,
    required this.folioRemision,
    required this.conductorId,
    required this.volumen,
    required this.obraFuture,
  });

  @override
  State<LiveTrackingFullscreenScreen> createState() =>
      _LiveTrackingFullscreenScreenState();
}

class _LiveTrackingFullscreenScreenState
    extends State<LiveTrackingFullscreenScreen> {
  static const _terminales = {'entregado', 'con_incidencia'};

  RutaRemision? _ruta;
  String? _errorText;
  GoogleMapViewController? _mapController;
  Timer? _timer;
  double _rotation = 0;

  /// Live marker/polyline, updated in place (`updateMarkers`/
  /// `updatePolylines`) rather than cleared and re-added every poll — that's
  /// what lets [glideMarkerTo] slide the truck smoothly between GPS pings
  /// instead of it snapping to the new position every 15s.
  Marker? _marker;
  Polyline? _polyline;
  Timer? _glide;
  final _rutaRestante = RutaRestantePolyline();
  final _recorrido = RecorridoPorCalles();

  LatLng? _destino;
  String? _destinoNombre;
  Marker? _marcadorDestino;
  bool _agregandoDestino = false;
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
      _destinoNombre = obra.nombre;
      _eta = RouteEtaTracker(destino: _destino!);
      _asegurarMarcadorDestino();
      final ultima = _ruta?.ultimaUbicacion;
      if (ultima != null) _actualizarEta(LatLng(latitude: ultima.latitud, longitude: ultima.longitud));
    });
  }

  /// Throttled inside [RouteEtaTracker] itself — see `_LiveTrackingCardState`'s
  /// identical method.
  Future<void> _actualizarEta(LatLng posicionActual) async {
    final eta = _eta;
    if (eta == null) return;
    final actualizado = await eta.actualizar(posicionActual);
    if (!actualizado || !mounted) return;
    setState(() {});
    await _dibujarRutaRestante(posicionActual);
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

  /// Adds the obra's llegada pin once, as soon as both the map and the
  /// destino are ready.
  Future<void> _asegurarMarcadorDestino() async {
    final controller = _mapController;
    final destino = _destino;
    if (controller == null || destino == null || !tieneCoordenadas(destino)) return;
    if (_marcadorDestino != null || _agregandoDestino) return;
    _agregandoDestino = true;
    try {
      final nuevos = await controller.addMarkers([
        MarkerOptions(
          position: destino,
          icon: await DestinoMarkerIcon.forColor(_accentYellow),
          anchor: DestinoMarkerIcon.anchor,
          infoWindow: InfoWindow(title: 'Llegada', snippet: _destinoNombre),
        ),
      ]);
      if (nuevos.isNotEmpty && nuevos.first != null) _marcadorDestino = nuevos.first;
    } catch (_) {
      // Best-effort — the map still works without the pin.
    } finally {
      _agregandoDestino = false;
    }
  }

  /// Road route still ahead — see `RutaRestantePolyline`. Only while the
  /// truck is heading to the obra; removed once it arrives.
  Future<void> _dibujarRutaRestante(LatLng posicionActual) async {
    final controller = _mapController;
    if (controller == null) return;
    final eta = _eta;
    final ruta = _ruta;
    if (eta == null || ruta == null || !vaHaciaObra(ruta.estatus)) {
      await _rutaRestante.quitar(controller);
      return;
    }
    await _rutaRestante.actualizar(controller, eta.rutaRestanteDesde(posicionActual), _accentYellow);
  }

  Future<void> _updateMapOverlays(
    RutaRemision ruta, {
    bool moverCamara = false,
  }) async {
    final controller = _mapController;
    final ultima = ruta.ultimaUbicacion;
    if (controller == null || ultima == null) return;
    unawaited(_asegurarMarcadorDestino());

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
      await _recorrido.actualizar(ruta.historial);
      final puntos = _recorrido.puntosParaDibujar(ruta.historial);
      final polilineaPrevia = _polyline;
      if (polilineaPrevia == null) {
        final nuevas = await controller.addPolylines([
          PolylineOptions(
            points: puntos,
            strokeColor: _accentYellow,
            strokeWidth: 4,
          ),
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

    await _dibujarRutaRestante(posicion);

    // Only recenters on load/first fix — once open, the user is expected to
    // pan/zoom freely (unlike the embedded card, gestures are enabled here),
    // so re-centering on every 15s poll would fight that.
    if (moverCamara) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(posicion, 16));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ruta = _ruta;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.folioRemision),
            if (widget.conductorId != null || widget.volumen != null)
              Text(
                [
                  if (widget.conductorId != null)
                    'Conductor #${widget.conductorId}',
                  if (widget.volumen != null) '${widget.volumen} m³',
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (ruta?.ultimaUbicacion != null)
            IconButton(
              tooltip: 'Centrar',
              icon: const Icon(Icons.my_location),
              onPressed: () => _updateMapOverlays(ruta!, moverCamara: true),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_errorText != null && ruta == null) {
            return Center(
              child: Text(_errorText!, textAlign: TextAlign.center),
            );
          }
          if (ruta == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ruta.ultimaUbicacion == null) {
            return const Center(
              child: Text('Esperando la primera señal GPS de este viaje.'),
            );
          }
          return Stack(
            children: [
              Positioned.fill(
                child: GoogleMapsMapView(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      latitude: ruta.ultimaUbicacion!.latitud,
                      longitude: ruta.ultimaUbicacion!.longitud,
                    ),
                    zoom: 16,
                  ),
                  initialMapColorScheme: isDark
                      ? MapColorScheme.dark
                      : MapColorScheme.light,
                  onViewCreated: (controller) {
                    _mapController = controller;
                    _updateMapOverlays(ruta, moverCamara: true);
                  },
                ),
              ),
              if (_eta?.progreso != null)
                Positioned(
                  top: 16,
                  bottom: 16,
                  right: 16,
                  child: RouteProgressBar(progreso: _eta!.progreso!),
                ),
              if (_velocidadKmh != null || _eta?.duracionRestanteSegundos != null)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: SpeedEtaPill(velocidadKmh: _velocidadKmh, duracionRestanteSegundos: _eta?.duracionRestanteSegundos),
                ),
            ],
          );
        },
      ),
    );
  }
}
