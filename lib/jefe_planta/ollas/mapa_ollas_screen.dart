import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../../auth/auth_service.dart';
import '../../direccion/live_tracking/vehicle_marker_icon.dart';
import '../../theme/app_colors.dart';
import '../jefe_planta_service.dart';
import '../jefe_planta_widgets.dart';
import 'mapa_ollas_widgets.dart';

/// Map of the ollas the Ollas tab is showing (one planta or all), or of a
/// single olla when [ollaId] is given, at their last known position from
/// operaciones `GET /vehiculos/ubicaciones`.
/// Re-polls ollas and positions every 15s, like Dirección's live tracking;
/// markers glide to their new position instead of jumping.
class MapaOllasScreen extends StatefulWidget {
  /// Null shows every planta's ollas.
  final int? plantaId;
  final ContextoPlanta? contexto;

  /// When given, only this olla is shown, centered, with its card open.
  final int? ollaId;

  /// [ollaId]'s unit number, for the title.
  final String? ollaNombre;

  const MapaOllasScreen({
    super.key,
    required this.plantaId,
    this.contexto,
    this.ollaId,
    this.ollaNombre,
  });

  @override
  State<MapaOllasScreen> createState() => _MapaOllasScreenState();
}

class _MapaOllasScreenState extends State<MapaOllasScreen> {
  static const _intervalo = Duration(seconds: 15);

  GoogleMapViewController? _controller;
  Timer? _timer;
  bool _cargando = true;
  String? _error;

  List<OllaPlanta> _ollas = const [];
  Map<int, UbicacionOlla> _ubicaciones = const {};
  int? _seleccion;

  /// Fit the camera once; re-fitting on every poll would fight the user.
  bool _camaraAjustada = false;

  final Map<int, Marker> _markers = {};
  final Map<int, Color> _coloresMarker = {};
  final Map<int, Timer> _glides = {};

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(_intervalo, (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final g in _glides.values) {
      g.cancel();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final results = await Future.wait<Object>([
        JefePlantaService.ollas(plantaId: widget.plantaId),
        JefePlantaService.ubicacionesOllas(),
      ]);
      if (!mounted) return;
      setState(() {
        _ollas = results[0] as List<OllaPlanta>;
        _ubicaciones = results[1] as Map<int, UbicacionOlla>;
        _cargando = false;
        _error = null;
      });
      await _actualizarMarkers();
    } on AuthException catch (e) {
      // A failed refresh keeps the last positions on screen.
      if (mounted && _cargando) {
        setState(() {
          _cargando = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted && _cargando) {
        setState(() {
          _cargando = false;
          _error = 'No se pudieron cargar las ubicaciones';
        });
      }
    }
  }

  List<(OllaPlanta, UbicacionOlla)> get _enMapa => [
    for (final o in _ollas)
      if (widget.ollaId == null || o.id == widget.ollaId)
        if (_ubicaciones[o.id] case final u?) (o, u),
  ];

  LatLng _latLng(UbicacionOlla u) =>
      LatLng(latitude: u.latitud, longitude: u.longitud);

  Future<void> _actualizarMarkers() async {
    final controller = _controller;
    if (controller == null) return;
    final visibles = _enMapa;
    final ids = {for (final (o, _) in visibles) o.id};

    final sobrantes = [
      for (final e in _markers.entries)
        if (!ids.contains(e.key)) e.value,
    ];
    if (sobrantes.isNotEmpty) {
      try {
        await controller.removeMarkers(sobrantes);
      } catch (_) {}
      _markers.removeWhere((id, _) => !ids.contains(id));
    }

    for (final (olla, u) in visibles) {
      final color = colorMarcadorOlla(olla, u);
      final previo = _markers[olla.id];
      final rotacion = u.heading ?? previo?.options.rotation ?? 0;
      try {
        if (previo == null || _coloresMarker[olla.id] != color) {
          // New olla, or its state changed: (re)create with the new color.
          if (previo != null) await controller.removeMarkers([previo]);
          final nuevos = await controller.addMarkers([
            MarkerOptions(
              position: _latLng(u),
              icon: await VehicleMarkerIcon.forColor(color),
              anchor: VehicleMarkerIcon.anchor,
              rotation: rotacion,
              zIndex: u.reciente ? 1 : 0,
              infoWindow: InfoWindow(title: olla.numeroUnidad),
            ),
          ]);
          final marker = nuevos.isNotEmpty ? nuevos.first : null;
          if (marker != null) {
            _markers[olla.id] = marker;
            _coloresMarker[olla.id] = color;
          }
        } else {
          _glides[olla.id]?.cancel();
          _glides[olla.id] = glideMarkerTo(
            controller,
            previo,
            toPosition: _latLng(u),
            toRotation: rotacion,
            duration: const Duration(seconds: 2),
            onUpdate: (m) => _markers[olla.id] = m,
          );
        }
      } catch (_) {}
    }

    if (!_camaraAjustada && visibles.isNotEmpty) {
      _camaraAjustada = true;
      final unica = widget.ollaId;
      if (unica != null) {
        await _seleccionar(unica, zoom: 15);
      } else {
        await _centrarEnTodas();
      }
    }
  }

  Future<void> _centrarEnTodas() async {
    final puntos = [for (final (_, u) in _enMapa) _latLng(u)];
    if (puntos.isEmpty) return;
    try {
      await _controller?.animateCamera(
        puntos.length == 1
            ? CameraUpdate.newLatLngZoom(puntos.first, 15)
            : CameraUpdate.newLatLngBounds(_bounds(puntos), padding: 80),
      );
    } catch (_) {}
  }

  Future<void> _seleccionar(int ollaId, {double? zoom}) async {
    final u = _ubicaciones[ollaId];
    setState(() => _seleccion = ollaId);
    if (u == null) return;
    try {
      await _controller?.animateCamera(
        zoom == null
            ? CameraUpdate.newLatLng(_latLng(u))
            : CameraUpdate.newLatLngZoom(_latLng(u), zoom),
      );
    } catch (_) {}
  }

  void _onMarkerClicked(String markerId) {
    for (final e in _markers.entries) {
      if (e.value.markerId == markerId) {
        _seleccionar(e.key);
        return;
      }
    }
  }

  static LatLngBounds _bounds(List<LatLng> puntos) {
    var minLat = puntos.first.latitude, maxLat = puntos.first.latitude;
    var minLng = puntos.first.longitude, maxLng = puntos.first.longitude;
    for (final p in puntos.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(latitude: minLat, longitude: minLng),
      northeast: LatLng(latitude: maxLat, longitude: maxLng),
    );
  }

  String _nombrePlanta(int? id) =>
      widget.contexto?.nombrePlanta(id) ??
      (id == null ? 'Sin planta' : 'Planta #$id');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt(context),
      appBar: AppBar(
        title: Text(
          widget.ollaId == null
              ? 'Ubicación de ollas'
              : 'Ubicación de ${widget.ollaNombre ?? 'la olla'}',
        ),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: AppColors.text(context),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: widget.ollaId == null ? 'Ver todas' : 'Centrar',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: _enMapa.isEmpty
                ? null
                : widget.ollaId == null
                ? _centrarEnTodas
                : () => _seleccionar(widget.ollaId!, zoom: 15),
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_cargando) return const JefePlantaCargando();
    if (_error != null) {
      return JefePlantaMensaje(
        icon: Icons.error_outline,
        mensaje: _error!,
        onRetry: () {
          setState(() {
            _cargando = true;
            _error = null;
          });
          _cargar();
        },
      );
    }
    final enMapa = _enMapa;
    if (enMapa.isEmpty) {
      return JefePlantaMensaje(
        icon: Icons.location_off_outlined,
        mensaje: widget.ollaId == null
            ? 'Ninguna olla está reportando su ubicación'
            : '${widget.ollaNombre ?? 'Esta olla'} no está reportando su ubicación',
      );
    }

    // A single olla's card stays open; there's nothing else to pick.
    final seleccion = widget.ollaId ?? _seleccion;
    final ollaSel = seleccion == null
        ? null
        : _ollas.where((o) => o.id == seleccion).firstOrNull;
    final ubicSel = seleccion == null ? null : _ubicaciones[seleccion];
    final primera = enMapa.first.$2;

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMapsMapView(
            initialCameraPosition: CameraPosition(
              target: _latLng(primera),
              zoom: 12,
            ),
            initialMapColorScheme: isDark
                ? MapColorScheme.dark
                : MapColorScheme.light,
            onMarkerClicked: _onMarkerClicked,
            onMapClicked: (_) {
              if (widget.ollaId == null && _seleccion != null) {
                setState(() => _seleccion = null);
              }
            },
            onViewCreated: (controller) {
              _controller = controller;
              _actualizarMarkers();
            },
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: ollaSel != null && ubicSel != null
              ? UbicacionOllaCard(
                  olla: ollaSel,
                  ubicacion: ubicSel,
                  plantaNombre: _nombrePlanta(ollaSel.plantaAsignadaId),
                  onCerrar: widget.ollaId != null
                      ? null
                      : () => setState(() => _seleccion = null),
                )
              : ResumenMapaOllasCard(
                  conUbicacion: enMapa.length,
                  sinSenalReciente: enMapa.where((e) => !e.$2.reciente).length,
                  sinUbicacion: _ollas.length - enMapa.length,
                ),
        ),
      ],
    );
  }
}
