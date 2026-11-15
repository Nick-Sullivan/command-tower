// The app icon: a square stone keep — a nod to the Command Tower card — with
// all five Magic colours pouring off its battlements.
//
// Everything is drawn on a square canvas of side `s`, which maps to Android's
// full 108dp adaptive-icon canvas: only the central 72dp is ever visible, and
// launchers may crop it to any shape, so the tower stays well inside it.
import 'dart:math';
import 'dart:ui';

/// One per Magic colour, as plain colour fields (not the mana symbols).
const fiveColours = [
  Color(0xFFF3E6BE), // white
  Color(0xFF2B7BC0), // blue
  Color(0xFF4A3F52), // black
  Color(0xFFD23A2E), // red
  Color(0xFF2E9A55), // green
];

const _stone = Color(0xFFF7F7F7);

/// Where the tower sits on the canvas.
Rect _towerBox(double s) => Rect.fromCenter(
  center: Offset(s / 2, s * .55),
  width: s * .6,
  height: s * .6,
);

/// Where the light leaves the top of the tower, in the tower's unit box.
const _towerTop = Offset(.5, .16);

/// Dark sky with the five colours fanning out from the top of the tower.
void paintBackground(Canvas canvas, double s) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = Gradient.radial(Offset(s / 2, s * .4), s * .75, [
        const Color(0xFF2A3042),
        const Color(0xFF12141B),
      ]),
  );
  final box = _towerBox(s);
  final tip = Offset(
    box.left + box.width * _towerTop.dx,
    box.top + box.height * _towerTop.dy,
  );
  const spread = pi * 1.15;
  const start = -pi / 2 - spread / 2;
  final sweep = spread / fiveColours.length;
  for (var i = 0; i < fiveColours.length; i++) {
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..arcTo(
          Rect.fromCircle(center: tip, radius: s * .3),
          start + i * sweep + sweep * .08,
          sweep * .84,
          false,
        )
        ..close(),
      Paint()
        ..shader = Gradient.radial(tip, s * .26, [
          fiveColours[i].withValues(alpha: .95),
          fiveColours[i].withValues(alpha: 0),
        ]),
    );
  }
  canvas.drawCircle(
    tip,
    s * .05,
    Paint()
      ..color = const Color(0xFFFFFFFF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .03),
  );
}

/// The tower on a transparent canvas, with a soft shadow unless [shadow] is
/// false (Android's monochrome themed icon wants the bare shape).
void paintForeground(Canvas canvas, double s, {bool shadow = true}) {
  final box = _towerBox(s);
  Offset p(double x, double y) =>
      Offset(box.left + x * box.width, box.top + y * box.height);
  Rect r(double l, double t, double rt, double b) =>
      Rect.fromPoints(p(l, t), p(rt, b));

  final body = Path()
    ..moveTo(p(.36, .88).dx, p(.36, .88).dy)
    ..lineTo(p(.38, .29).dx, p(.38, .29).dy)
    ..lineTo(p(.62, .29).dx, p(.62, .29).dy)
    ..lineTo(p(.64, .88).dx, p(.64, .88).dy)
    ..close()
    // Parapet, overhanging the body a little.
    ..addRect(r(.365, .24, .635, .30))
    // Corner turrets, taller than the merlon between them.
    ..addRect(r(.365, .14, .44, .25))
    ..addRect(r(.56, .14, .635, .25))
    ..addRect(r(.47, .185, .53, .25))
    // Plinth.
    ..addRect(r(.33, .88, .67, .92));

  if (shadow) {
    canvas.drawPath(
      body.shift(Offset(0, box.height * .012)),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, box.width * .02),
    );
  }

  // Openings are cut out so whatever is behind shows through.
  canvas.saveLayer(Rect.fromLTWH(0, 0, s, s), Paint());
  canvas.drawPath(body, Paint()..color = _stone);
  final cut = Paint()..blendMode = BlendMode.clear;
  RRect arch(Rect rect) => RRect.fromRectAndCorners(
    rect,
    topLeft: Radius.circular(rect.width / 2),
    topRight: Radius.circular(rect.width / 2),
  );
  // Tall arched windows under the parapet.
  canvas.drawRRect(arch(r(.42, .34, .47, .50)), cut);
  canvas.drawRRect(arch(r(.53, .34, .58, .50)), cut);
  // Stone band around the middle.
  canvas.drawRect(r(.34, .585, .66, .60), cut);
  // Doorway.
  canvas.drawRRect(arch(r(.465, .78, .535, .88)), cut);
  canvas.restore();
}

/// Background and tower together.
void paintIcon(Canvas canvas, double s) {
  paintBackground(canvas, s);
  paintForeground(canvas, s);
}
