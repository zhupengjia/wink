import 'dart:math';
import 'package:flutter/material.dart';

/// Represents a star in the background
class Star {
  final double x; // Normalized position (0-1)
  final double y;
  final double z; // Depth (0-1, 0 = far, 1 = close)
  final double brightness;
  final double twinkleOffset; // For animation variation

  const Star({
    required this.x,
    required this.y,
    required this.z,
    required this.brightness,
    required this.twinkleOffset,
  });
}

/// Custom painter for the animated starfield background
class StarfieldPainter extends CustomPainter {
  final List<Star> stars;
  final Offset panOffset;
  final double zoom;
  final double time; // Animation time (0-1)

  StarfieldPainter({
    required this.stars,
    required this.panOffset,
    required this.zoom,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      // Parallax effect based on depth
      final parallax = 1 + star.z * 0.5;
      final x = (star.x + panOffset.dx * parallax * 0.1) * size.width;
      final y = (star.y + panOffset.dy * parallax * 0.1) * size.height;

      // Wrap around screen edges
      final wrappedX = x % size.width;
      final wrappedY = y % size.height;

      // Skip if somehow off screen
      if (wrappedX < 0 || wrappedX > size.width ||
          wrappedY < 0 || wrappedY > size.height) {
        continue;
      }

      // Twinkle effect
      final twinklePhase = (time * 2 * pi + star.twinkleOffset) % (2 * pi);
      final twinkle = (sin(twinklePhase) + 1) / 2;
      final alpha = (star.brightness * 0.5 + twinkle * 0.5).clamp(0.0, 1.0);

      // Star color (slight blue/white tint for distant stars)
      final color = Color.lerp(
        Colors.white.withOpacity(alpha * 0.6),
        Colors.blueAccent.withOpacity(alpha * 0.4),
        star.z,
      )!;

      final paint = Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.5 + star.z);

      // Size based on depth
      final radius = 0.5 + (1 - star.z) * 1.5;

      canvas.drawCircle(Offset(wrappedX, wrappedY), radius, paint);
    }

    // Add some nebula-like gradient in the center
    final centerGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.5,
      colors: [
        const Color(0xFF8B5CF6).withOpacity(0.03),
        const Color(0xFFEC4899).withOpacity(0.02),
        Colors.transparent,
      ],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradientPaint = Paint()
      ..shader = centerGradient.createShader(rect);
    canvas.drawRect(rect, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoom != zoom;
  }
}

/// Generate a list of stars with random positions and properties
List<Star> generateStars(int count, {int? seed}) {
  final random = Random(seed ?? 42); // Seeded for consistency
  return List.generate(count, (_) {
    return Star(
      x: random.nextDouble(),
      y: random.nextDouble(),
      z: random.nextDouble(),
      brightness: 0.3 + random.nextDouble() * 0.7,
      twinkleOffset: random.nextDouble() * 2 * pi,
    );
  });
}
