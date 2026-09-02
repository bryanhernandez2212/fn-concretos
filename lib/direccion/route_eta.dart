import 'package:google_navigation_flutter/google_navigation_flutter.dart' show LatLng;
import 'directions_service.dart';

/// Tracks a remisión's remaining distance/duration/progress to [destino] by
/// periodically calling [DirectionsService], throttled to at most once every
/// [_minInterval] regardless of how often [actualizar] is called — real
/// routing calls are billed per request, so this stays deliberately coarser
/// than the 15s GPS/position poll it's driven from.
///
/// `progreso` is computed against the *first* successful call's remaining
/// distance (treated as the route's total), not a fixed original plan — if
/// the truck deviates from Directions' suggested route the number will
/// drift, same trade-off DiDi-style progress bars generally accept rather
/// than paying for a full route-matching/snap-to-road system.
class RouteEtaTracker {
  final LatLng destino;

  RouteEtaTracker({required this.destino});

  static const _minInterval = Duration(seconds: 60);
  DateTime? _ultimaConsulta;
  int? _distanciaTotalMetros;

  int? distanciaRestanteMetros;
  int? duracionRestanteSegundos;

  /// 0.0-1.0, or null until the first successful route lookup.
  double? get progreso {
    final total = _distanciaTotalMetros;
    final restante = distanciaRestanteMetros;
    if (total == null || total <= 0 || restante == null) return null;
    return (1 - (restante / total)).clamp(0, 1);
  }

  /// Returns true if this call actually refreshed the numbers (so the
  /// caller knows whether a `setState` is worth triggering) — false when
  /// throttled or the request failed.
  Future<bool> actualizar(LatLng posicionActual) async {
    final ahora = DateTime.now();
    if (_ultimaConsulta != null && ahora.difference(_ultimaConsulta!) < _minInterval) return false;
    _ultimaConsulta = ahora;

    final ruta = await DirectionsService.rutaHacia(origen: posicionActual, destino: destino);
    if (ruta == null) return false;

    _distanciaTotalMetros ??= ruta.distanciaMetros;
    distanciaRestanteMetros = ruta.distanciaMetros;
    duracionRestanteSegundos = ruta.duracionSegundos;
    return true;
  }
}

/// "45 min" or "1h 20min" — used by the live-tracking ETA pill.
String formatEta(int segundos) {
  final minutos = (segundos / 60).round();
  if (minutos < 60) return '$minutos min';
  final horas = minutos ~/ 60;
  final resto = minutos % 60;
  return resto == 0 ? '${horas}h' : '${horas}h ${resto}min';
}
