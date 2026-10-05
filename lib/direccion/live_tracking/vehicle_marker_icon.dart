import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../operaciones/remision_tracking.dart';

class VehicleMarkerIcon {
  VehicleMarkerIcon._();

  static const anchor = MarkerAnchor(u: 0.5, v: 0.5);

  static final Map<int, Future<ImageDescriptor>> _cache = {};

  static Future<ImageDescriptor> forColor(Color color) {
    return _cache.putIfAbsent(color.toARGB32(), () => _render(color));
  }

  /// Logical size of the drawing, front facing up. Rendered at
  /// [_escala]x and registered with the same pixel ratio, so it shows at
  /// this size on the map and stays sharp on high-density screens.
  static const tamano = Size(36, 56);
  static const _escala = 4.0;

  static Future<ImageDescriptor> _render(Color color) async {
    final bytes = await renderPng(color);
    return registerBitmapImage(bitmap: bytes, imagePixelRatio: _escala);
  }

  /// PNG of the olla for [color]. Separate from [_render] so it can be
  /// previewed without a map.
  static Future<ByteData> renderPng(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_escala);
    paint(canvas, color);
    final image = await recorder.endRecording().toImage(
      (tamano.width * _escala).round(),
      (tamano.height * _escala).round(),
    );
    return (await image.toByteData(format: ui.ImageByteFormat.png))!;
  }

  /// A compact top-down concrete mixer (olla revolvedora), shaded to look
  /// solid the way ride-hailing apps' car sprites do: a drop shadow and
  /// cylinder-style gradients on the cab and drum. Kept short and wide on
  /// purpose — a long, striped drum read as a worm at map size. Drawn front
  /// up, so `MarkerOptions.rotation` (degrees clockwise from north) needs no
  /// offset. [color] paints the cab and the drum's two bands.
  static void paint(Canvas canvas, Color color) {
    final oscuro = Color.lerp(color, Colors.black, 0.45)!;
    final claro = Color.lerp(color, Colors.white, 0.35)!;

    // Drop shadow, offset down-right as if lit from the top-left.
    canvas.drawRRect(
      _rr(5, 2, 26, 50, 8).shift(const Offset(1.5, 2.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Chassis, then wheels peeking out at the sides (front axle, two rear).
    canvas.drawRRect(_rr(7, 15, 22, 36, 3), Paint()..color = const Color(0xFF2A2D31));
    final llanta = Paint()..color = const Color(0xFF111316);
    for (final y in [8.0, 36.0, 44.0]) {
      for (final x in [3.0, 29.0]) {
        canvas.drawRRect(_rr(x, y, 4, 6, 1.2), llanta);
      }
    }

    // Drum: a metallic barrel with two bands in the route color.
    const tambor = Rect.fromLTWH(6, 19, 24, 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tambor, const Radius.circular(11)),
      Paint()
        ..shader = _cilindro(tambor, const [Color(0xFF7E8388), Color(0xFFF6F7F8), Color(0xFFD5D8DB), Color(0xFF63686D)]),
    );
    final banda = Paint()
      ..color = oscuro.withValues(alpha: 0.55)
      ..strokeWidth = 1.6;
    for (final y in [27.0, 37.0]) {
      canvas.drawLine(Offset(7, y), Offset(29, y), banda);
    }

    // Cab, windshield, and a light outline so it stays legible on dark tiles.
    const cabinaRect = Rect.fromLTWH(5, 2, 26, 15);
    final cabina = RRect.fromRectAndCorners(
      cabinaRect,
      topLeft: const Radius.circular(9),
      topRight: const Radius.circular(9),
      bottomLeft: const Radius.circular(2),
      bottomRight: const Radius.circular(2),
    );
    canvas.drawRRect(cabina, Paint()..shader = _cilindro(cabinaRect, [oscuro, claro, color, oscuro]));
    canvas.drawRRect(
      _rr(8, 4.5, 20, 5, 3),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF9FC3DC), Color(0xFF1C2A36)],
        ).createShader(const Rect.fromLTWH(8, 4.5, 20, 5)),
    );
    canvas.drawRRect(
      cabina,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  static RRect _rr(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  /// Left-to-right shading that makes a flat shape read as a cylinder.
  static Shader _cilindro(Rect rect, List<Color> colores) =>
      LinearGradient(colors: colores, stops: const [0, 0.35, 0.65, 1]).createShader(rect);
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

/// Speed in km/h derived from two consecutive position reports plus their
/// timestamps — like [bearingBetween], nothing in `GpsPing`/
/// `RutaRemisionResponse` reports speed directly, so both are computed
/// client-side from the same two points. Null if either timestamp is
/// missing/unparseable or they're not far enough apart in time to give a
/// meaningful reading.
double? speedKmhBetween(GpsPing from, GpsPing to) {
  final t1 = DateTime.tryParse(from.timestampCaptura ?? '');
  final t2 = DateTime.tryParse(to.timestampCaptura ?? '');
  if (t1 == null || t2 == null) return null;
  final segundos = t2.difference(t1).inSeconds;
  if (segundos <= 0) return null;
  final metros = geo.Geolocator.distanceBetween(from.latitud, from.longitud, to.latitud, to.longitud);
  return (metros / segundos) * 3.6;
}

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
