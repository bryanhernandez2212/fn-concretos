import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';

/// Full-screen, fully interactive map (unlike the read-only, gesture-disabled
/// `GoogleMapsMapView`s used for live tracking elsewhere) for pinning an
/// obra's exact location — the coordinates conductores rely on for
/// turn-by-turn navigation (`route_navigation_screen.dart`), so a
/// device-current-position guess isn't precise enough on its own: the
/// advisor can pan/zoom to the obra's actual entrance and drop the pin
/// there, the same way they'd do it by hand in the Google Maps app.
/// Pops with the picked [LatLng], or `null` if cancelled.
class ObraLocationPickerScreen extends StatefulWidget {
  final LatLng? initial;

  const ObraLocationPickerScreen({super.key, this.initial});

  @override
  State<ObraLocationPickerScreen> createState() => _ObraLocationPickerScreenState();
}

class _ObraLocationPickerScreenState extends State<ObraLocationPickerScreen> {
  static const _fallbackCenter = LatLng(latitude: 23.6345, longitude: -102.5528); // Mexico, camera fallback only

  GoogleMapViewController? _mapController;
  LatLng? _picked;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    if (widget.initial == null) _centrarEnUbicacionActual(silencioso: true);
  }

  Future<void> _centrarEnUbicacionActual({bool silencioso = false}) async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      if (!granted) {
        if (!silencioso && mounted) AppSnack.error(context, 'Se necesita el permiso de ubicación');
        return;
      }
      final posicion = await Geolocator.getCurrentPosition();
      final controller = _mapController;
      if (controller != null) {
        await controller.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(latitude: posicion.latitude, longitude: posicion.longitude),
              zoom: 17,
            ),
          ),
        );
      }
    } catch (_) {
      if (!silencioso && mounted) AppSnack.error(context, 'No se pudo obtener la ubicación');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _marcar(LatLng posicion) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.clearMarkers();
    await controller.addMarkers([MarkerOptions(position: posicion)]);
    setState(() => _picked = posicion);
  }

  void _confirmar() {
    final picked = _picked;
    if (picked == null) return;
    Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación de la obra'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMapsMapView(
              initialCameraPosition: CameraPosition(target: widget.initial ?? _fallbackCenter, zoom: widget.initial != null ? 17 : 4),
              initialMapColorScheme: isDark ? MapColorScheme.dark : MapColorScheme.light,
              onMapClicked: _marcar,
              onViewCreated: (controller) async {
                _mapController = controller;
                final initial = widget.initial;
                if (initial != null) await _marcar(initial);
              },
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 18, color: textColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Toca el mapa para marcar la ubicación exacta de la obra',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'obra-mi-ubicacion',
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              foregroundColor: textColor,
              onPressed: _locating ? null : () => _centrarEnUbicacionActual(),
              child: _locating
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 88,
            child: ElevatedButton(
              onPressed: _picked == null ? null : _confirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_picked == null ? 'Marca un punto en el mapa' : 'Confirmar ubicación', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
