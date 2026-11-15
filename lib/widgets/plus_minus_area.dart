import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sound/sounds.dart';

/// A surface whose left half lowers a value and right half raises it: tap for
/// 1, hold to repeat in steps of 10. The pressed half lights up, and every
/// change gives a light haptic click. [child] is drawn on top and ignores
/// touches.
class PlusMinusArea extends StatefulWidget {
  const PlusMinusArea({
    super.key,
    required this.onChange,
    required this.child,
    this.markSize = 32,
  });

  final ValueChanged<int> onChange;
  final Widget child;

  /// Size of the faint − and + marks at the edges.
  final double markSize;

  @override
  State<PlusMinusArea> createState() => _PlusMinusAreaState();
}

class _PlusMinusAreaState extends State<PlusMinusArea> {
  static const _repeatEvery = Duration(milliseconds: 600);
  static const _pressedColor = Color(0x33FFFFFF);
  static const _releaseFade = Duration(milliseconds: 250);

  /// Fingers currently down on each half, keyed by sign. Counted rather than
  /// flagged so a second finger lifting doesn't clear the first's highlight.
  final _fingersDown = {-1: 0, 1: 0};
  Timer? _repeatTimer;

  void _apply(int change) {
    // The keyboard-key click. selectionClick (a "tick") is lighter, but many
    // phones play it at zero strength. Android still skips this when the user
    // has touch feedback turned off.
    HapticFeedback.lightImpact();
    SoundScope.tap(context, change.sign);
    widget.onChange(change);
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
            padding: EdgeInsets.symmetric(horizontal: widget.markSize / 2),
            child: Text(
              mark,
              style: TextStyle(
                color: const Color(0x59FFFFFF),
                fontSize: widget.markSize,
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          children: [
            _half(-1, '−', Alignment.centerLeft),
            _half(1, '+', Alignment.centerRight),
          ],
        ),
        IgnorePointer(child: widget.child),
      ],
    );
  }
}
