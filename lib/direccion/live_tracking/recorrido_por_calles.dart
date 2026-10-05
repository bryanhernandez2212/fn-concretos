import 'package:google_navigation_flutter/google_navigation_flutter.dart' show LatLng;
import '../../operaciones/remision_tracking.dart';
import 'directions_service.dart';

/// Turns one remisión's GPS `historial` (which the backend only returns as
/// raw pings) into the path along the streets, via
/// [DirectionsService.rutaPorPuntos], for the "ya recorrido" trail.
///
/// The pings are split into fixed tramos of [_puntosPorTramo] points, each
/// one's last point being the next one's first. A full tramo never changes
/// once routed, so it's cached for good. Only the last, still-growing tramo
/// is re-routed as new pings arrive, at most once every [_minInterval]
/// (billed per request). Whatever hasn't been routed yet, or failed, is
/// drawn as straight lines between pings, same as before.
class RecorridoPorCalles {
  /// Origin + 10 `via` points + destination: the most Routes API allows on
  /// its basic (Essentials) SKU.
  static const _puntosPorTramo = 12;
  static const _minInterval = Duration(seconds: 60);

  /// Pings closer than this to the previous kept one are dropped (truck
  /// stopped or crawling). Greedy from the start, so adding pings at the end
  /// never changes which earlier pings were kept, and tramos stay stable.
  static const _separacionMinimaMetros = 25.0;

  /// Routed path per tramo index, with how many of that tramo's points it
  /// covered when routed (fewer than [_puntosPorTramo] for the last one).
  final Map<int, ({int puntos, List<LatLng> trazado})> _tramos = {};
  DateTime? _ultimaConsultaParcial;

  /// Routes whatever tramos are missing or have grown. Full tramos are
  /// fetched right away (once each, in parallel), the growing last one only
  /// if [_minInterval] has passed. Returns true if anything new was routed.
  Future<bool> actualizar(List<GpsPing> historial) async {
    final puntos = _filtrar(historial);
    final pendientes = <int>[];
    var incluyeParcial = false;
    for (var i = 0; i * (_puntosPorTramo - 1) < puntos.length - 1; i++) {
      final tramo = _tramo(puntos, i);
      final guardado = _tramos[i];
      if (guardado != null && guardado.puntos >= tramo.length) continue;
      if (tramo.length < _puntosPorTramo) {
        final ultima = _ultimaConsultaParcial;
        if (ultima != null && DateTime.now().difference(ultima) < _minInterval) continue;
        incluyeParcial = true;
      }
      pendientes.add(i);
    }
    if (pendientes.isEmpty) return false;
    if (incluyeParcial) _ultimaConsultaParcial = DateTime.now();

    final resultados = await Future.wait(pendientes.map((i) async {
      final tramo = _tramo(puntos, i);
      final trazado = await DirectionsService.rutaPorPuntos(tramo);
      if (trazado == null || trazado.length < 2) return false;
      _tramos[i] = (puntos: tramo.length, trazado: trazado);
      return true;
    }));
    return resultados.contains(true);
  }

  /// The trail to draw right now: routed tramos where available, straight
  /// lines between pings for the rest (including pings newer than the last
  /// routing), ending at the latest ping.
  List<LatLng> puntosParaDibujar(List<GpsPing> historial) {
    final puntos = _filtrar(historial);
    final salida = <LatLng>[];
    for (var i = 0; i * (_puntosPorTramo - 1) < puntos.length - 1; i++) {
      final tramo = _tramo(puntos, i);
      final guardado = _tramos[i];
      if (guardado == null || guardado.puntos > tramo.length) {
        salida.addAll(tramo);
      } else {
        salida.addAll(guardado.trazado);
        salida.addAll(tramo.skip(guardado.puntos));
      }
    }
    final ultimo = historial.isEmpty ? null : historial.last;
    if (ultimo != null) salida.add(LatLng(latitude: ultimo.latitud, longitude: ultimo.longitud));
    return salida;
  }

  static List<LatLng> _tramo(List<LatLng> puntos, int indice) {
    final inicio = indice * (_puntosPorTramo - 1);
    final fin = (inicio + _puntosPorTramo).clamp(0, puntos.length);
    return puntos.sublist(inicio, fin);
  }

  static List<LatLng> _filtrar(List<GpsPing> historial) {
    final puntos = <LatLng>[];
    for (final ping in historial) {
      final punto = LatLng(latitude: ping.latitud, longitude: ping.longitud);
      if (puntos.isEmpty || distanciaMetros(puntos.last, punto) >= _separacionMinimaMetros) {
        puntos.add(punto);
      }
    }
    return puntos;
  }
}
