import 'package:flutter/material.dart';

class StripedPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double stripeWidth;

  StripedPainter({
    required this.color1,
    required this.color2,
    this.stripeWidth = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    // Draw background color
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    // Draw diagonal stripes
    Path path = Path();
    // Start drawing from way off-screen to ensure full coverage
    double startX = -size.height * 2;
    
    while (startX < size.width) {
      path.moveTo(startX, 0);
      path.lineTo(startX + stripeWidth, 0);
      path.lineTo(startX + stripeWidth + size.height, size.height);
      path.lineTo(startX + size.height, size.height);
      path.close();
      
      canvas.drawPath(path, paint2);
      
      startX += stripeWidth * 2;
    }
  }

  @override
  bool shouldRepaint(covariant StripedPainter oldDelegate) {
    return oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.stripeWidth != stripeWidth;
  }
}

class StripedBanner extends StatelessWidget {
  final double height;
  final Color color1;
  final Color color2;

  const StripedBanner({
    super.key,
    this.height = 12.0,
    this.color1 = const Color(0xFFFFCC00), // primaryYellow
    this.color2 = const Color(0xFFD4A000), // Darker yellow/orange
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: StripedPainter(
          color1: color1,
          color2: color2,
          stripeWidth: 15.0,
        ),
      ),
    );
  }
}
