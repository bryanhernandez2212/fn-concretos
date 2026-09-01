import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../operaciones/remision_tracking.dart';

/// Renders and registers the vehicle-shaped marker used on Dirección's
/// live-tracking maps (`PedidoDetailScreen`'s "Ubicación en vivo" and
/// `RutasActivasScreen`) so a moving remisión reads like a rideshare app's
/// top-down vehicle puck instead of the default static map pin.
///
/// `registerBitmapImage` is a process-wide registry, not scoped to one
/// `GoogleMapViewController` (see `google_maps_image_registry.dart`), so the
/// resulting [ImageDescriptor] is cached per color here — one registration
/// per route color for the lifetime of the app, not per poll/rebuild.
class VehicleMarkerIcon {
  VehicleMarkerIcon._();

  /// The car shape below is drawn centered in its canvas (front at the top),
  /// so it must be anchored at its geometric center. `MarkerOptions`'s
  /// default anchor, `(0.5, 1.0)`, is meant for pins that point down from a
  /// bottom tip; using it here would offset the car upward from its real
  /// position and make `rotation` swing it around the wrong point.
  static const anchor = MarkerAnchor(u: 0.5, v: 0.5);

  static final Map<int, Future<ImageDescriptor>> _cache = {};

  static Future<ImageDescriptor> forColor(Color color) {
    return _cache.putIfAbsent(color.toARGB32(), () => _render(color));
  }

  /// Draws a simple top-down car silhouette — body, windshield, rear
  /// window, mirrors — rather than a generic icon glyph on a colored puck.
  /// Drawn with its front already facing up/north at rotation 0, matching
  /// how `MarkerOptions.rotation` measures degrees clockwise from north, so
  /// no extra rotation is needed the way a font glyph would.
  static Future<ImageDescriptor> _render(Color color) async {
    const double w = 64;
    const double h = 112;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final body = Rect.fromLTWH(w * 0.12, h * 0.04, w * 0.76, h * 0.92);

    // White halo first so the car stays legible over both light and dark
    // map tiles/traffic colors, same reasoning as this app's other
    // theme-aware overlays.
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.inflate(4), const Radius.circular(18)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(15)),
      Paint()..color = color,
    );

    // Windshield near the front.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.10, w * 0.56, h * 0.17),
        const Radius.circular(7),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );

    // Rear window.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.75, w * 0.56, h * 0.12),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    // Side mirrors.
    final mirrorPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.16, w * 0.1, h * 0.05),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.9, h * 0.16, w * 0.1, h * 0.05),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.round(), h.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return registerBitmapImage(bitmap: bytes!, imagePixelRatio: 3);
  }
}

/// Forward azimuth (degrees clockwise from north, 0-360) from [from] to [to]
/// — what [MarkerOptions.rotation] expects. Neither `GpsPing` nor
/// `RutaRemisionResponse` carries a heading from the backend, so this is
/// derived client-side from consecutive position reports.
double bearingBetween(GpsPing from, GpsPing to) {
  final lat1 = from.latitud * math.pi / 180;
  final lat2 = to.latitud * math.pi / 180;
  final dLon = (to.longitud - from.longitud) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final bearingRad = math.atan2(y, x);
  return (bearingRad * 180 / math.pi + 360) % 360;
}

/// Slides [marker] from its current position/rotation to [toPosition]/
/// [toRotation] over [duration] (ticking every 200ms via `updateMarkers`)
/// instead of snapping it there on the next poll — so a truck reads as
/// continuously moving between GPS pings rather than teleporting every 15s.
/// Cancel the returned [Timer] (e.g. before starting a new glide for the
/// same marker) to stop it early; each tick's updated [Marker] is handed to
/// [onUpdate] so the caller can track it as the *next* glide's starting
/// point, since markers in this package are immutable.
Timer glideMarkerTo(
  GoogleMapViewController controller,
  Marker marker, {
  required LatLng toPosition,
  required double toRotation,
  required Duration duration,
  required void Function(Marker updated) onUpdate,
}) {
  final fromPosition = marker.options.position;
  final fromRotation = marker.options.rotation;
  final stopwatch = Stopwatch()..start();
  var current = marker;

  late final Timer timer;
  timer = Timer.periodic(const Duration(milliseconds: 200), (t) async {
    final progress = (stopwatch.elapsedMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);
    final updated = current.copyWith(
      options: current.options.copyWith(
        position: _lerpLatLng(fromPosition, toPosition, progress),
        rotation: _lerpRotation(fromRotation, toRotation, progress),
      ),
    );
    try {
      final result = await controller.updateMarkers([updated]);
      current = (result.isNotEmpty ? result.first : null) ?? updated;
    } catch (_) {
      // A transient platform-view hiccup mid-glide shouldn't kill the
      // ticker — just keep going from the locally-computed position.
      current = updated;
    }
    onUpdate(current);
    if (progress >= 1.0) t.cancel();
  });
  return timer;
}

LatLng _lerpLatLng(LatLng from, LatLng to, double t) {
  return LatLng(
    latitude: from.latitude + (to.latitude - from.latitude) * t,
    longitude: from.longitude + (to.longitude - from.longitude) * t,
  );
}

/// Shortest-path rotation lerp so a heading change from e.g. 350° to 10°
/// glides forward through 0°/360° instead of spinning the long way around.
double _lerpRotation(double from, double to, double t) {
  var delta = (to - from) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return (from + delta * t + 360) % 360;
}
