import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const playerColors = [
  Color(0xFFC0392B), // red
  Color(0xFF2E86C1), // blue
  Color(0xFF27AE60), // green
  Color(0xFFD68910), // amber
  Color(0xFF8E44AD), // purple
  Color(0xFF546E7A), // slate
];

/// Formats a number with a true minus sign, which reads better than a hyphen
/// at large sizes.
String formatNumber(int n, {bool signed = false}) {
  if (n < 0) return '−${-n}';
  return signed ? '+$n' : '$n';
}

/// One player's life total. The left half lowers it, the right half raises
/// it; tap for 1, hold to repeat in steps of 10. Laid out upright for the
/// player, so wrap it in a [RotatedBox] to face their seat.
class PlayerPanel extends StatefulWidget {
  const PlayerPanel({
    super.key,
    required this.life,
    required this.color,
    required this.onChange,
  });

  final int life;
  final Color color;
  final ValueChanged<int> onChange;

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
  static const _deltaVisibleFor = Duration(seconds: 2);
  static const _repeatEvery = Duration(milliseconds: 600);

  static const _pressedColor = Color(0x33FFFFFF);
  static const _releaseFade = Duration(milliseconds: 250);

  int _delta = 0;
  bool _showDelta = false;

  /// Fingers currently down on each half, keyed by sign. Counted rather than
  /// flagged so a second finger lifting doesn't clear the first's highlight.
  final _fingersDown = {-1: 0, 1: 0};
  Timer? _deltaTimer;
  Timer? _repeatTimer;

  void _apply(int change) {
    // The lightest haptic there is; Android skips it when the user has
    // touch feedback turned off.
    HapticFeedback.selectionClick();
    widget.onChange(change);
    setState(() {
      // A change after the last delta faded starts a fresh count.
      if (!_showDelta) _delta = 0;
      _delta += change;
      _showDelta = true;
    });
    _deltaTimer?.cancel();
    _deltaTimer = Timer(_deltaVisibleFor, () {
      if (mounted) setState(() => _showDelta = false);
    });
  }

  void _startRepeat(int sign) {
    _apply(10 * sign);
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(_repeatEvery, (_) => _apply(10 * sign));
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _deltaTimer?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _fingerChange(int sign, int by) {
    setState(() => _fingersDown[sign] = _fingersDown[sign]! + by);
  }

  Widget _half(int sign, String mark, Alignment alignment) {
    final pressed = _fingersDown[sign]! > 0;
    // A Listener sees every finger without competing with the tap and hold
    // gestures below it.
    return Expanded(
      child: Listener(
        onPointerDown: (_) => _fingerChange(sign, 1),
        onPointerUp: (_) => _fingerChange(sign, -1),
        onPointerCancel: (_) => _fingerChange(sign, -1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _apply(sign),
          onLongPressStart: (_) => _startRepeat(sign),
          onLongPressEnd: (_) => _stopRepeat(),
          onLongPressCancel: _stopRepeat,
          child: AnimatedContainer(
            key: ValueKey(('half', sign)),
            // Light up instantly on press; fade out on release.
            duration: pressed ? Duration.zero : _releaseFade,
            color: pressed ? _pressedColor : _pressedColor.withAlpha(0),
            alignment: alignment,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              mark,
              style: const TextStyle(
                color: Color(0x59FFFFFF),
                fontSize: 32,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.color,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Row(
            children: [
              _half(-1, '−', Alignment.centerLeft),
              _half(1, '+', Alignment.centerRight),
            ],
          ),
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: h * 0.14,
                        width: w * 0.3,
                        child: AnimatedOpacity(
                          opacity: _showDelta ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: FittedBox(
                            child: Text(
                              formatNumber(_delta, signed: true),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: h * 0.5,
                        width: w * 0.6,
                        child: FittedBox(
                          child: Text(
                            formatNumber(widget.life),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 120,
                              fontWeight: FontWeight.w600,
                              height: 1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: h * 0.14),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
