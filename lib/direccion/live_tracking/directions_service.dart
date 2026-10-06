import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart' show LatLng;
import '../../config/http_client.dart' as http;

/// Result of one `DirectionsService.rutaHacia` call: real road-network
/// distance/duration for the route actually returned (Routes API always
/// answers with the current-best route, not a fixed original plan), plus
/// that route's path along the streets for drawing on the map.
class RouteResult {
  final int distanciaMetros;
  final int duracionSegundos;
  final List<LatLng> puntos;

  const RouteResult({required this.distanciaMetros, required this.duracionSegundos, required this.puntos});
}

/// Talks to Google's Routes API (`routes.googleapis.com/directions/v2:
/// computeRoutes`) — a plain REST call, not a native SDK, using the same Maps
/// Platform API key already embedded in `android/app/src/main/
/// AndroidManifest.xml`/`ios/Runner/AppDelegate.swift`. Replaced the classic
/// Directions API: one call returns the ETA and the encoded road polyline, so
/// drawing the route costs no extra requests.
///
/// This exists because a passive `GoogleMapsMapView` watching someone
/// else's position has no ETA/progress of its own — that's normally a
/// Navigation-SDK-guidance-session feature, tied to whoever is actively
/// navigating (`deliveries/navegacion/route_navigation_screen.dart`'s conductor-side
/// screen), not something a remote viewer (Dirección watching an olla/bomba)
/// can read off the map. `direccion/live_tracking/route_eta.dart`'s `RouteEtaTracker` is
/// the throttled wrapper actually used by the live-tracking screens.
class DirectionsService {
  static const _apiKey = 'AIzaSyDp4VbFAq1b6Qc6KZgLnV1tc8kqWz1UFEg';

  static Future<RouteResult?> rutaHacia({required LatLng origen, required LatLng destino}) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.https('routes.googleapis.com', '/directions/v2:computeRoutes'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          // Only the fields read below. Anything more is billed at a higher SKU.
          'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
        },
        body: jsonEncode({
          'origin': _waypoint(origen),
          'destination': _waypoint(destino),
          'travelMode': 'DRIVE',
        }),
      );
    } catch (_) {
      return null;
    }
    if (response.statusCode != 200) {
      debugPrint('[rastreo] Routes API ${response.statusCode}: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      return null;
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      // `duration` comes as a string like "676s". `distanceMeters` is left
      // out of the JSON when it's 0 (origin already at destino).
      final duracion = int.tryParse((route['duration'] as String? ?? '').replaceAll('s', ''));
      final distancia = route['distanceMeters'] as int? ?? 0;
      final encoded = (route['polyline'] as Map<String, dynamic>?)?['encodedPolyline'] as String?;
      if (duracion == null) return null;

      return RouteResult(
        distanciaMetros: distancia,
        duracionSegundos: duracion,
        puntos: encoded == null ? const [] : decodePolyline(encoded),
      );
    } catch (_) {
      return null;
    }
  }

  /// Road path the truck actually drove through [puntos] (its GPS pings, in
  /// order): Routes API routes from the first to the last one passing through
  /// the rest as `via` waypoints, so the trail follows the streets instead
  /// of straight lines between pings. At most 10 in-between points per call,
  /// which keeps the request on Routes API's basic (Essentials) SKU — callers
  /// split longer trails into tramos (see `RecorridoPorCalles`). Returns null
  /// on any failure, or when the result is a detour far longer than the pings
  /// themselves (e.g. a ping off the road network), so the caller keeps the
  /// straight lines instead of drawing a wrong route.
  static Future<List<LatLng>?> rutaPorPuntos(List<LatLng> puntos) async {
    if (puntos.length < 2 || puntos.length > 12) return null;
    final http.Response response;
    try {
      response = await http.post(
        Uri.https('routes.googleapis.com', '/directions/v2:computeRoutes'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'routes.distanceMeters,routes.polyline.encodedPolyline',
        },
        body: jsonEncode({
          'origin': _waypoint(puntos.first),
          'destination': _waypoint(puntos.last),
          'intermediates': [
            for (final punto in puntos.sublist(1, puntos.length - 1)) {..._waypoint(punto), 'via': true},
          ],
          'travelMode': 'DRIVE',
        }),
      );
    } catch (_) {
      return null;
    }
    if (response.statusCode != 200) {
      debugPrint('[rastreo] Routes API ${response.statusCode}: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      return null;
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final encoded = (route['polyline'] as Map<String, dynamic>?)?['encodedPolyline'] as String?;
      if (encoded == null) return null;

      var enLineaRecta = 0.0;
      for (var i = 1; i < puntos.length; i++) {
        enLineaRecta += distanciaMetros(puntos[i - 1], puntos[i]);
      }
      final distancia = route['distanceMeters'] as int? ?? 0;
      if (distancia > enLineaRecta * 2.5 + 500) return null;

      return decodePolyline(encoded);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _waypoint(LatLng punto) => {
        'location': {
          'latLng': {'latitude': punto.latitude, 'longitude': punto.longitude},
        },
      };
}

/// Decodes Google's encoded polyline format (5-digit precision), as returned
/// by Routes API's `encodedPolyline`.
List<LatLng> decodePolyline(String encoded) {
  final puntos = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  int siguienteValor() {
    var resultado = 0;
    var desplazamiento = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      resultado |= (byte & 0x1f) << desplazamiento;
      desplazamiento += 5;
    } while (byte >= 0x20);
    return (resultado & 1) != 0 ? ~(resultado >> 1) : resultado >> 1;
  }

  while (index < encoded.length) {
    lat += siguienteValor();
    lng += siguienteValor();
    puntos.add(LatLng(latitude: lat / 1e5, longitude: lng / 1e5));
  }
  return puntos;
}

/// Approximate distance in meters (equirectangular — plenty for the short
/// hops between GPS pings).
double distanciaMetros(LatLng a, LatLng b) {
  const radioTierra = 6371000.0;
  final x = (b.longitude - a.longitude) * math.pi / 180 * math.cos((a.latitude + b.latitude) * math.pi / 360);
  final y = (b.latitude - a.latitude) * math.pi / 180;
  return math.sqrt(x * x + y * y) * radioTierra;
}
