import 'dart:convert';
import 'package:google_navigation_flutter/google_navigation_flutter.dart' show LatLng;
import 'package:http/http.dart' as http;

/// Result of one `DirectionsService.rutaHacia` call: real road-network
/// distance/duration for the leg actually returned (Directions API always
/// answers with the current-best route, not a fixed original plan).
class RouteResult {
  final int distanciaMetros;
  final int duracionSegundos;

  const RouteResult({required this.distanciaMetros, required this.duracionSegundos});
}

/// Talks to Google's classic Directions API (`maps.googleapis.com/maps/api/
/// directions`) — a plain REST call, not a native SDK, using the same Maps
/// Platform API key already embedded in `android/app/src/main/
/// AndroidManifest.xml`/`ios/Runner/AppDelegate.swift`. Already enabled on
/// the `fnconcretos` Cloud project (confirmed in the same Cloud Console
/// session that found Navigation SDK access missing — Directions API was
/// already on the key's restriction list, a normal self-serve API unlike
/// Navigation SDK's gated approval).
///
/// This exists because a passive `GoogleMapsMapView` watching someone
/// else's position has no ETA/progress of its own — that's normally a
/// Navigation-SDK-guidance-session feature, tied to whoever is actively
/// navigating (`deliveries/route_navigation_screen.dart`'s conductor-side
/// screen), not something a remote viewer (Dirección watching an olla/bomba)
/// can read off the map. `direccion/route_eta.dart`'s `RouteEtaTracker` is
/// the throttled wrapper actually used by the live-tracking screens.
class DirectionsService {
  static const _apiKey = 'AIzaSyDp4VbFAq1b6Qc6KZgLnV1tc8kqWz1UFEg';

  static Future<RouteResult?> rutaHacia({required LatLng origen, required LatLng destino}) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origen.latitude},${origen.longitude}',
      'destination': '${destino.latitude},${destino.longitude}',
      'key': _apiKey,
    });
    final http.Response response;
    try {
      response = await http.get(uri);
    } catch (_) {
      return null;
    }
    if (response.statusCode != 200) return null;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    if (data['status'] != 'OK') return null;

    final routes = data['routes'] as List<dynamic>?;
    final legs = routes != null && routes.isNotEmpty ? (routes.first as Map<String, dynamic>)['legs'] as List<dynamic>? : null;
    if (legs == null || legs.isEmpty) return null;
    final leg = legs.first as Map<String, dynamic>;
    final distancia = (leg['distance'] as Map<String, dynamic>?)?['value'] as int?;
    final duracion = (leg['duration'] as Map<String, dynamic>?)?['value'] as int?;
    if (distancia == null || duracion == null) return null;

    return RouteResult(distanciaMetros: distancia, duracionSegundos: duracion);
  }
}
