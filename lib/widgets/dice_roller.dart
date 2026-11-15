import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../sound/sounds.dart';

import '../game/dice.dart';
import '../settings/app_settings.dart';

/// The dice button beside the ⚙. Tapping it pops the dice chosen in
/// Tracking out just above it, right on the table; tap a die to roll it.
/// Tapping anywhere else (or the button again) tucks them away.
class DiceButton extends StatefulWidget {
  const DiceButton({super.key, required this.settings, this.random});

  final AppSettings settings;

  /// For tests; a fresh [Random] otherwise.
  final Random? random;

  @override
  State<DiceButton> createState() => _DiceButtonState();
}

class _DiceButtonState extends State<DiceButton> {
  final _popout = OverlayPortalController();
  late final Random _random = widget.random ?? Random();

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _popout,
      overlayChildBuilder: (context) => _DicePopout(
        dice: widget.settings.diceShown,
        random: _random,
        onClose: _popout.hide,
      ),
      child: Material(
        color: Colors.black,
        shape: const CircleBorder(),
        child: IconButton(
          key: const ValueKey('dice-button'),
          icon: const Icon(Icons.casino, color: Colors.white70),
          onPressed: _popout.toggle,
        ),
      ),
    );
  }
}

class _DicePopout extends StatelessWidget {
  const _DicePopout({
    required this.dice,
    required this.random,
    required this.onClose,
  });

  final List<Die> dice;
  final Random random;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        // Any tap off the dice closes them, including on the dice button.
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('dice-dismiss'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
          ),
        ),
        // Just above the ⚙ and dice buttons, which sit mid-screen.
        Positioned(
          left: 16,
          right: 16,
          bottom: screen.height / 2 + 36,
          child: Center(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              elevation: 6,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final die in dice)
                      _DieButton(die: die, random: random),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One die: shows its name until rolled, then its result. Tap to roll; the
/// result tumbles briefly, then lands with a click.
class _DieButton extends StatefulWidget {
  const _DieButton({required this.die, required this.random});

  final Die die;
  final Random random;

  @override
  State<_DieButton> createState() => _DieButtonState();
}

class _DieButtonState extends State<_DieButton> {
  static const _tumbleFor = Duration(milliseconds: 600);
  static const _tumbleEvery = Duration(milliseconds: 60);
  static const _size = 72.0;

  int? _result;
  bool _rolling = false;
  Timer? _tumble;

  @override
  void dispose() {
    _tumble?.cancel();
    super.dispose();
  }

  void _roll() {
    if (_rolling) return;
    final die = widget.die;
    final landing = die.roll(widget.random);
    var elapsed = Duration.zero;
    setState(() {
      _rolling = true;
      _result = die.roll(widget.random);
    });
    _tumble = Timer.periodic(_tumbleEvery, (timer) {
      elapsed += _tumbleEvery;
      if (elapsed >= _tumbleFor) {
        timer.cancel();
        SoundScope.vibrate(context);
        setState(() {
          _rolling = false;
          _result = landing;
        });
      } else {
        setState(() => _result = die.roll(widget.random));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _result;
    return Material(
      key: ValueKey(('die', widget.die.name)),
      color: scheme.primaryContainer,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _roll,
        child: SizedBox.square(
          dimension: _size,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: result == null
                ? FittedBox(
                    child: Text(
                      widget.die.label,
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.die.label,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          child: Text(
                            widget.die.show(result),
                            key: ValueKey(('die-result', widget.die.name)),
                            style: TextStyle(
                              // Faded while it tumbles, solid once it lands.
                              color: scheme.onPrimaryContainer.withValues(
                                alpha: _rolling ? 0.4 : 1,
                              ),
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
