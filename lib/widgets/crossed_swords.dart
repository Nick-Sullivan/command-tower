import 'package:flutter/material.dart';

/// Two crossed swords, hilts down: the commander damage symbol. Drawn here
/// because Material Icons has no sword.
class CrossedSwords extends StatelessWidget {
  const CrossedSwords({super.key, this.size = 24, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SwordsPainter(color));
  }
}

class _SwordsPainter extends CustomPainter {
  _SwordsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;

    // Sword with its hilt at the bottom left, pointing to the top right; the
    // second is its mirror image.
    for (final mirror in [false, true]) {
      Offset p(double x, double y) => Offset((mirror ? 1 - x : x) * s, y * s);
      canvas.drawLine(p(.30, .70), p(.88, .12), stroke); // blade
      canvas.drawLine(p(.20, .60), p(.40, .80), stroke); // crossguard
      canvas.drawLine(p(.30, .70), p(.17, .83), stroke); // grip
      canvas.drawCircle(p(.14, .86), s * .07, fill); // pommel
    }
  }

  @override
  bool shouldRepaint(_SwordsPainter old) => old.color != color;
}
