import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

/// The obra's "llegada" pin on Dirección's live-tracking maps: a map pin in
/// the route's color with a checkered finish flag, so each truck's
/// destination is visible and, on `RutasActivasScreen`, matched to its
/// truck by color.
class DestinoMarkerIcon {
  DestinoMarkerIcon._();

  /// The pin's tip sits on the obra's coordinates.
  static const anchor = MarkerAnchor(u: 0.5, v: 1);

  static const tamano = Size(34, 46);
  static const _escala = 4.0;

  static final Map<int, Future<ImageDescriptor>> _cache = {};

  static Future<ImageDescriptor> forColor(Color color) {
    return _cache.putIfAbsent(color.toARGB32(), () async {
      final bytes = await renderPng(color);
      return registerBitmapImage(bitmap: bytes, imagePixelRatio: _escala);
    });
  }

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

  static void paint(Canvas canvas, Color color) {
    final w = tamano.width;
    final h = tamano.height;
    final centro = Offset(w / 2, w / 2);
    final radio = w / 2 - 2;

    // Soft contact shadow under the tip.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - 2), width: w * 0.4, height: 3.5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Teardrop as one outline: the circle's arc over the top, from ~40° either
    // side of straight down, then both sides curving in to the tip.
    const apertura = 40 * math.pi / 180;
    final punta = Offset(w / 2, h - 3);
    final pin = Path()
      ..addArc(Rect.fromCircle(center: centro, radius: radio), math.pi / 2 + apertura, 2 * math.pi - 2 * apertura)
      ..quadraticBezierTo(w / 2 + radio * 0.3, h * 0.8, punta.dx, punta.dy)
      ..quadraticBezierTo(w / 2 - radio * 0.3, h * 0.8, centro.dx - radio * math.sin(apertura), centro.dy + radio * math.cos(apertura))
      ..close();
    canvas.drawPath(
      pin,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.25)!, Color.lerp(color, Colors.black, 0.3)!],
        ).createShader(Offset.zero & tamano),
    );
    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // White disc holding the checkered flag.
    canvas.drawCircle(centro, radio * 0.68, Paint()..color = Colors.white);

    // Flag pole.
    final poste = Offset(centro.dx - radio * 0.34, centro.dy - radio * 0.42);
    canvas.drawLine(
      poste,
      poste.translate(0, radio * 0.9),
      Paint()
        ..color = const Color(0xFF15181B)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    // Checkered cloth, 3 columns x 2 rows.
    final celda = radio * 0.22;
    final origen = poste.translate(0.7, 0);
    for (var fila = 0; fila < 2; fila++) {
      for (var col = 0; col < 3; col++) {
        canvas.drawRect(
          Rect.fromLTWH(origen.dx + col * celda, origen.dy + fila * celda, celda, celda),
          Paint()..color = (fila + col).isEven ? const Color(0xFF15181B) : Colors.white,
        );
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(origen.dx, origen.dy, celda * 3, celda * 2),
      Paint()
        ..color = const Color(0xFF15181B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }
}

/// An obra with no coordinates comes back as 0,0 (see `Obra.fromJson`) —
/// no pin for those rather than one off the coast of Africa.
bool tieneCoordenadas(LatLng punto) => punto.latitude != 0 || punto.longitude != 0;
