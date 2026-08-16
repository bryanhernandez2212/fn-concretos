import 'dart:math' as math;
import 'package:flutter/material.dart';

const _accentYellow = Color(0xFFFFCC00);

/// Pure-design login background: a checkered grid of white lines drifting
/// diagonally toward the bottom-right corner, plus small white and yellow
/// dots drifting upward, over solid black. Replaces the old background
/// image asset.
class LoginBackground extends StatefulWidget {
  const LoginBackground({super.key});

  @override
  State<LoginBackground> createState() => _LoginBackgroundState();
}

class _LoginBackgroundState extends State<LoginBackground>
    with TickerProviderStateMixin {
  static const _gridSize = 46.0;
  late final AnimationController _gridController;
  late final AnimationController _dotsController;
  final _random = math.Random();
  late final List<_Dot> _dots = List.generate(55, (_) => _Dot.random(_random));

  @override
  void initState() {
    super.initState();
    _gridController = AnimationController(vsync: this, duration: const Duration(seconds: 11))..repeat();
    _dotsController = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(() {
        for (final dot in _dots) {
          dot.advance(_random);
        }
      })
      ..repeat();
  }

  @override
  void dispose() {
    _gridController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: Listenable.merge([_gridController, _dotsController]),
        builder: (context, _) => CustomPaint(
          painter: _BackgroundPainter(
            gridOffset: _gridController.value * _gridSize,
            gridSize: _gridSize,
            dots: _dots,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Draws the drifting grid lines first, then the drifting dots on top.
class _BackgroundPainter extends CustomPainter {
  final double gridOffset;
  final double gridSize;
  final List<_Dot> dots;

  _BackgroundPainter({required this.gridOffset, required this.gridSize, required this.dots});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (double x = gridOffset - gridSize; x < size.width + gridSize; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = gridOffset - gridSize; y < size.height + gridSize; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final dot in dots) {
      dotPaint.color = dot.color.withValues(alpha: dot.opacity);
      canvas.drawCircle(Offset(dot.x * size.width, dot.y * size.height), dot.radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) => true;
}

/// A single dot drifting upward; position is stored as a fraction (0..1)
/// of the canvas so it scales with any screen size. Resets just below the
/// bottom edge once it drifts past the top, so the upward flow is
/// continuous.
class _Dot {
  double x;
  double y;
  final double radius;
  final double speed;
  final double opacity;
  final Color color;

  _Dot({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
    required this.color,
  });

  factory _Dot.random(math.Random random) {
    return _Dot(
      x: random.nextDouble(),
      y: random.nextDouble(),
      radius: 1.5 + random.nextDouble() * 3,
      speed: 0.0004 + random.nextDouble() * 0.0011,
      opacity: 0.25 + random.nextDouble() * 0.55,
      color: random.nextBool() ? Colors.white : _accentYellow,
    );
  }

  void advance(math.Random random) {
    y -= speed;
    if (y < -0.05) {
      y = 1 + random.nextDouble() * 0.2;
      x = random.nextDouble();
    }
  }
}
