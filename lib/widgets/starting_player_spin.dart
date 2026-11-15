import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reveals who goes first: a highlight hops around the table in seat order,
/// slowing down, and lands on [chosen], whose border then stays lit. Ignores
/// touches; the table clears it on the first one.
class StartingPlayerSpin extends StatefulWidget {
  const StartingPlayerSpin({
    super.key,
    required this.seatRects,
    required this.chosen,
  });

  /// Each seat's panel, on screen, in clockwise seat order.
  final List<Rect> seatRects;
  final int chosen;

  /// Roughly how long the spin takes before landing.
  static const duration = Duration(milliseconds: 1500);

  @override
  State<StartingPlayerSpin> createState() => _StartingPlayerSpinState();
}

class _StartingPlayerSpinState extends State<StartingPlayerSpin> {
  int _seat = 0;
  bool _landed = false;
  Timer? _timer;

  /// Two full laps, then on to the chosen seat.
  late final _hops = 2 * widget.seatRects.length + widget.chosen;

  @override
  void initState() {
    super.initState();
    _hop(0);
  }

  /// Hops are quick at first and slow towards the end, adding up to about
  /// [StartingPlayerSpin.duration].
  void _hop(int hop) {
    if (hop == _hops) {
      HapticFeedback.lightImpact();
      setState(() => _landed = true);
      return;
    }
    final t = hop / _hops;
    final total = StartingPlayerSpin.duration.inMilliseconds;
    // Delays grow with t²; their sum over the hops is about [total].
    final delay = (3 * total * t * t / _hops).round() + 20;
    _timer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _seat = (hop + 1) % widget.seatRects.length);
      _hop(hop + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.seatRects[_seat];
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: AnimatedContainer(
          key: const ValueKey('starting-player-highlight'),
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: _landed ? 1 : 0.7),
              width: _landed ? 6 : 4,
            ),
            // The glow is outside the border only, so the panel's own colour
            // isn't washed out.
            boxShadow: _landed
                ? const [
                    BoxShadow(
                      color: Color(0x99FFFFFF),
                      blurRadius: 18,
                      spreadRadius: 2,
                      blurStyle: BlurStyle.outer,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
