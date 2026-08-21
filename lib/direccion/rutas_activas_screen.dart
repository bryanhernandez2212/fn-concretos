import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/remision_tracking.dart';
import '../theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final habiaCamiones = _remisiones.isNotEmpty;
    try {
      final remisiones = await OperacionesService.remisionesEnRuta();
      final rutas = <int, RutaRemision>{};
      for (final remision in remisiones) {
        try {
          rutas[remision.id] = await OperacionesService.rutaRemision(remision.id);
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
      await controller.clearMarkers();
      await controller.clearPolylines();

      final posiciones = <LatLng>[];
      for (final (index, remision) in _remisiones.indexed) {
        final ruta = _rutas[remision.id];
        final ultima = ruta?.ultimaUbicacion;
        if (ultima == null) continue;
        final posicion = LatLng(latitude: ultima.latitud, longitude: ultima.longitud);
        posiciones.add(posicion);

        await controller.addMarkers([
          MarkerOptions(
            position: posicion,
            infoWindow: InfoWindow(
              title: remision.folioRemision,
              snippet: [
                if (remision.conductorId != null) 'Conductor #${remision.conductorId}',
                remision.estatus.replaceAll('_', ' '),
              ].join(' · '),
            ),
          ),
        ]);

        if ((ruta?.historial.length ?? 0) > 1) {
          await controller.addPolylines([
            PolylineOptions(
              points: ruta!.historial
                  .map((p) => LatLng(latitude: p.latitud, longitude: p.longitud))
                  .toList(),
              strokeColor: _routeColors[index % _routeColors.length],
              strokeWidth: 4,
            ),
          ]);
        }
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
      CameraUpdate.newLatLngZoom(LatLng(latitude: ultima.latitud, longitude: ultima.longitud), 15),
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
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas activas'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
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
              Text(_errorInicial!, textAlign: TextAlign.center, style: TextStyle(color: mutedColor)),
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

    return Column(
      children: [
        SizedBox(
          height: 320,
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
                  initialMapColorScheme: isDark ? MapColorScheme.dark : MapColorScheme.light,
                  onViewCreated: (controller) {
                    _mapController = controller;
                    _actualizarMapa();
                  },
                ),
        ),
        Expanded(
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
                    onTap: tieneUbicacion ? () => _centrarEn(remision.id) : null,
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
                              color: _routeColors[index % _routeColors.length],
                            ),
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
                              ],
                            ),
                          ),
                          if (!tieneUbicacion)
                            Text(
                              'Sin señal',
                              style: TextStyle(fontSize: 11.5, color: mutedColor),
                            )
                          else
                            Icon(Icons.my_location, size: 18, color: mutedColor),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
