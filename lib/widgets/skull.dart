import 'package:flutter/material.dart';

/// A skull, for lethal damage. Eyes, nose and teeth are cut out so whatever
/// is behind shows through. Drawn here because Material Icons has no skull.
class Skull extends StatelessWidget {
  const Skull({super.key, this.size = 24, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SkullPainter(color));
  }
}

class _SkullPainter extends CustomPainter {
  _SkullPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final bone = Paint()..color = color;
    final hole = Paint()..blendMode = BlendMode.clear;

    canvas.saveLayer(Offset.zero & size, Paint());
    // Cranium and jaw.
    canvas.drawCircle(p(.5, .42), s * .38, bone);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(.28 * s, .55 * s, .72 * s, .92 * s),
        Radius.circular(s * .08),
      ),
      bone,
    );
    // Eyes.
    canvas.drawOval(
      Rect.fromCenter(center: p(.34, .48), width: s * .2, height: s * .22),
      hole,
    );
    canvas.drawOval(
      Rect.fromCenter(center: p(.66, .48), width: s * .2, height: s * .22),
      hole,
    );
    // Nose.
    canvas.drawPath(
      Path()
        ..moveTo(.5 * s, .6 * s)
        ..lineTo(.44 * s, .71 * s)
        ..lineTo(.56 * s, .71 * s)
        ..close(),
      hole,
    );
    // Gaps between the teeth.
    final gap = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = s * .05;
    for (final x in [.4, .5, .6]) {
      canvas.drawLine(p(x, .79), p(x, .92), gap);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkullPainter old) => old.color != color;
}
