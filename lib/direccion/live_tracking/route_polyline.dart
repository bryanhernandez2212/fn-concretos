import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

/// Hitos where the truck is still driving toward the obra — the only ones
/// where the remaining road route is worth drawing.
const _estatusHaciaObra = {'salio_planta', 'en_camino', 'proximo_llegar'};

bool vaHaciaObra(String estatus) => _estatusHaciaObra.contains(estatus);

/// The "por recorrer" road route from the truck to the obra, drawn from
/// `RouteEtaTracker.rutaRestanteDesde` next to the GPS trail it already
/// traveled. Updated in place rather than re-added on every poll, same as
/// the trail. A lighter, wider stroke of the trail's color tells them apart.
class RutaRestantePolyline {
  Polyline? _polyline;

  /// Both the 15s poll and a finished route lookup draw this line, possibly
  /// at the same time. Running them one after another keeps two concurrent
  /// first draws from each adding their own polyline.
  Future<void> _cola = Future.value();

  Future<void> _enCola(Future<void> Function() operacion) {
    // Best-effort: a platform-view hiccup just leaves the previous line.
    return _cola = _cola.then((_) => operacion()).catchError((_) {});
  }

  /// Draws [puntos], or removes the line when there are fewer than two.
  Future<void> actualizar(GoogleMapViewController controller, List<LatLng> puntos, Color color) =>
      _enCola(() => _actualizar(controller, puntos, color));

  Future<void> quitar(GoogleMapViewController controller) => _enCola(() => _quitar(controller));

  Future<void> _actualizar(GoogleMapViewController controller, List<LatLng> puntos, Color color) async {
    if (puntos.length < 2) return _quitar(controller);

    final previa = _polyline;
    if (previa == null) {
      final nuevas = await controller.addPolylines([
        PolylineOptions(points: puntos, strokeColor: color.withValues(alpha: 0.45), strokeWidth: 6),
      ]);
      if (nuevas.isNotEmpty && nuevas.first != null) _polyline = nuevas.first;
    } else {
      final actualizadas = await controller.updatePolylines([
        previa.copyWith(options: previa.options.copyWith(points: puntos)),
      ]);
      if (actualizadas.isNotEmpty && actualizadas.first != null) _polyline = actualizadas.first;
    }
  }

  Future<void> _quitar(GoogleMapViewController controller) async {
    final previa = _polyline;
    if (previa == null) return;
    _polyline = null;
    await controller.removePolylines([previa]);
  }
}
