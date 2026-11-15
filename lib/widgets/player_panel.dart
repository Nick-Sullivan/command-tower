import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game.dart';
import '../sound/sounds.dart';
import 'counter_icon.dart';
import 'turn_clock.dart';
import 'crossed_swords.dart';
import 'plus_minus_area.dart';
import 'skull.dart';

const playerColors = [
  Color(0xFFC0392B), // red
  Color(0xFF2E86C1), // blue
  Color(0xFF27AE60), // green
  Color(0xFFD68910), // amber
  Color(0xFF8E44AD), // purple
  Color(0xFFD81B60), // pink
];

/// Formats a number with a true minus sign, which reads better than a hyphen
/// at large sizes.
String formatNumber(int n, {bool signed = false}) {
  if (n < 0) return '−${-n}';
  return signed ? '+$n' : '$n';
}

/// Another player, as seen from a panel: who they are and how much commander
/// damage this panel's player has taken from them.
class Opponent {
  const Opponent({
    required this.player,
    required this.color,
    required this.damage,
  });

  final int player;
  final Color color;
  final int damage;
}

/// One of the counters turned on in settings, and this player's value.
class CounterValue {
  const CounterValue(this.counter, this.value);

  final Counter counter;
  final int value;
}

/// One player's panel, laid out upright for them; wrap it in a [RotatedBox]
/// to face their seat.
///
/// It always shows one thing big: their life total, or — after tapping a
/// button in the bar along the bottom — the commander damage they've taken
/// from each opponent (placed left to right as they sit around the table), or
/// one of their counters. Tapping the same button again goes back to life.
class PlayerPanel extends StatefulWidget {
  const PlayerPanel({
    super.key,
    required this.life,
    required this.color,
    this.knockedOut = false,
    required this.opponents,
    this.commanderDamage = true,
    this.counters = const [],
    required this.onLifeChange,
    required this.onDamageChange,
    this.onCounterChange,
    this.turnElapsed,
    this.onEndTurn,
  });

  final int life;
  final Color color;

  /// Fogs the panel over. Everything still works, since some cards let a
  /// player keep going.
  final bool knockedOut;

  /// Ordered left to right from this player's seat.
  final List<Opponent> opponents;
  final ValueChanged<int> onLifeChange;

  /// Changes damage taken from opponent `from` by `delta`; returns how much
  /// it actually changed (damage can't go below 0).
  final int Function(int from, int delta) onDamageChange;

  /// Whether commander damage is tracked: shows the swords button.
  final bool commanderDamage;

  /// The counters turned on in settings, in bar order.
  final List<CounterValue> counters;
  final void Function(Counter counter, int delta)? onCounterChange;

  /// When it's this player's turn and the turn timer is on: how long the
  /// turn has run. The panel is outlined and shows the time, which is also
  /// the button that ends the turn.
  final ValueGetter<Duration>? turnElapsed;
  final VoidCallback? onEndTurn;

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
  static const _deltaVisibleFor = Duration(seconds: 2);

  bool _damageMode = false;

  /// The counter shown big, if any. Ignored if it's since been turned off.
  Counter? _counterMode;
  CounterValue? get _shownCounter {
    for (final cv in widget.counters) {
      if (cv.counter == _counterMode) return cv;
    }
    return null;
  }

  int _delta = 0;
  bool _showDelta = false;
  Timer? _deltaTimer;

  /// Shows a running total of recent life changes, which fades once they
  /// stop.
  void _trackLifeChange(int change) {
    if (change == 0) return;
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

  void _changeLife(int delta) {
    widget.onLifeChange(delta);
    _trackLifeChange(delta);
  }

  void _changeDamage(int from, int delta) {
    final changed = widget.onDamageChange(from, delta);
    _trackLifeChange(-changed);
    _restartViewTimeout();
  }

  // No haptics when switching views: the click is reserved for changes to
  // the numbers.
  void _toggleDamageMode() {
    setState(() {
      _damageMode = !_damageMode;
      _counterMode = null;
    });
    _restartViewTimeout();
  }

  void _toggleCounter(Counter counter) {
    setState(() {
      _counterMode = _shownCounter?.counter == counter ? null : counter;
      _damageMode = false;
    });
    _restartViewTimeout();
  }

  /// How long commander damage or a counter stays shown without a tap
  /// before the panel goes back to life, so it's never left showing the
  /// wrong thing.
  static const _viewTimeout = Duration(seconds: 5);
  Timer? _viewTimer;

  void _restartViewTimeout() {
    _viewTimer?.cancel();
    if (!_damageMode && _counterMode == null) return;
    _viewTimer = Timer(_viewTimeout, () {
      if (mounted) {
        setState(() {
          _damageMode = false;
          _counterMode = null;
        });
      }
    });
  }

  void _changeCounter(Counter counter, int delta) {
    widget.onCounterChange?.call(counter, delta);
    _restartViewTimeout();
  }

  @override
  void didUpdateWidget(PlayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only at the moment it happens: not for a game reopened with someone
    // already out, and not again while they stay out.
    if (!oldWidget.knockedOut && widget.knockedOut) {
      SoundScope.knockedOut(context);
    }
  }

  @override
  void dispose() {
    _deltaTimer?.cancel();
    _viewTimer?.cancel();
    super.dispose();
  }

  /// A grey haze over a knocked-out panel: the colour still shows through,
  /// but everything reads as out of play.
  static const _fog = Color(0x99505050);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.color,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final barHeight = (size.height * 0.22).clamp(44.0, 72.0);
              final counter = _shownCounter;
              // Damage mode is ignored if it's since been turned off.
              if (_damageMode && widget.commanderDamage) {
                return _damageView(size, barHeight);
              }
              if (counter != null) {
                return _counterView(counter, size, barHeight);
              }
              return _lifeView(size, barHeight);
            },
          ),
          // Over everything, but never in the way: a knocked-out player can
          // still be kept alive by a card.
          IgnorePointer(
            child: AnimatedOpacity(
              key: const ValueKey('fog'),
              opacity: widget.knockedOut ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: const ColoredBox(color: _fog),
            ),
          ),
          // Whose turn it is.
          if (widget.turnElapsed != null)
            IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('turn-border'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lifeView(Size size, double barHeight) {
    return Stack(
      children: [
        PlusMinusArea(
          onChange: _changeLife,
          // The total gets all the room above the button bar, so it's as big
          // as the panel allows, side panels included.
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, area) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: area.maxHeight * 0.18,
                          width: area.maxWidth * 0.3,
                          // A knocked-out player gets a skull above their
                          // total, as lethal commander damage does; a running
                          // change takes its place while it's showing.
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedOpacity(
                                opacity: widget.knockedOut && !_showDelta
                                    ? 1
                                    : 0,
                                duration: const Duration(milliseconds: 300),
                                child: const FittedBox(
                                  child: Skull(
                                    key: ValueKey('knocked-out-skull'),
                                    size: 48,
                                  ),
                                ),
                              ),
                              _deltaText(),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: area.maxHeight * 0.74,
                          width: area.maxWidth * 0.75,
                          child: FittedBox(
                            child: _twoDigitWide(
                              formatNumber(widget.life),
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 120,
                                fontWeight: FontWeight.w600,
                                height: 1,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: barHeight),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: barHeight,
          child: _bar(barHeight, showLife: false),
        ),
      ],
    );
  }

  /// [text] laid out at least as wide as "00", so a FittedBox draws 9 and
  /// 40 at the same size rather than blowing single digits up.
  static Widget _twoDigitWide(String text, TextStyle style) => Stack(
    alignment: Alignment.center,
    children: [
      Opacity(opacity: 0, child: Text('00', style: style)),
      Text(text, style: style),
    ],
  );

  Widget _counterView(CounterValue shown, Size size, double barHeight) {
    final counter = shown.counter;
    const style = TextStyle(
      color: Colors.white,
      fontSize: 120,
      fontWeight: FontWeight.w600,
      height: 1,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Stack(
      children: [
        PlusMinusArea(
          key: ValueKey(('counter-area', counter.name)),
          // Counters aren't health, so they don't play sounds.
          sound: false,
          onChange: (d) => _changeCounter(counter, d * counter.step),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: size.height * 0.14,
                  child: FittedBox(
                    child: Icon(counterIcons[counter], color: Colors.white70),
                  ),
                ),
                SizedBox(
                  height: size.height * 0.5,
                  width: size.width * 0.6,
                  // An invisible "00" keeps 1 and 10 the same size.
                  child: FittedBox(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Opacity(
                          opacity: 0,
                          child: Text('00', style: style),
                        ),
                        Text(formatNumber(shown.value), style: style),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.14),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: barHeight,
          child: _bar(barHeight, showLife: true),
        ),
      ],
    );
  }

  Widget _damageView(Size size, double barHeight) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Row(
              children: [
                for (final opponent in widget.opponents)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _DamageArea(
                        key: ValueKey(('damage-from', opponent.player)),
                        opponent: opponent,
                        onChange: (d) => _changeDamage(opponent.player, d),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: barHeight, child: _bar(barHeight, showLife: true)),
      ],
    );
  }

  /// The row of buttons along the bottom: swords, then each counter, then end
  /// turn on the player whose turn it is. They stay centred in every view, so
  /// the button that opened a view is under your finger to close it. Away
  /// from the life view, the life total sits to their right; the turn's time
  /// sits to their left.
  Widget _bar(double barHeight, {required bool showLife}) {
    final turnElapsed = widget.turnElapsed;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          // Equal space either side keeps the buttons centred.
          const Expanded(child: SizedBox()),
          ConstrainedBox(
            // Room for the life total beside them; on a narrow panel the
            // buttons shrink rather than overflow.
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.7),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.commanderDamage) _swordsButton(barHeight),
                  for (final cv in widget.counters)
                    _counterButton(cv, barHeight),
                  if (turnElapsed != null) _turnPill(turnElapsed, barHeight),
                ],
              ),
            ),
          ),
          _barLife(barHeight, showLife: showLife),
        ],
      ),
    );
  }

  Widget _barLife(double barHeight, {required bool showLife}) {
    return Expanded(
      child: showLife
          ? Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatNumber(widget.life),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: barHeight * 0.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(height: barHeight * 0.3, child: _deltaText()),
                  ],
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  /// The turn: how long it's been going, and ending it, in one solid pill
  /// so the time and the button that resets it are together. The whole pill
  /// ends the turn.
  Widget _turnPill(ValueGetter<Duration> elapsed, double barHeight) {
    final height = (barHeight * 0.75).clamp(36.0, 48.0);
    final foreground = widget.color;
    return GestureDetector(
      key: const ValueKey('end-turn'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        SoundScope.vibrate(context);
        widget.onEndTurn?.call();
      },
      child: Container(
        height: barHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: Container(
          height: height,
          padding: EdgeInsets.only(left: height * 0.3, right: height * 0.15),
          decoration: const ShapeDecoration(
            shape: StadiumBorder(),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, size: height * 0.5, color: foreground),
              SizedBox(width: height * 0.15),
              TurnClock(
                elapsed: elapsed,
                style: TextStyle(
                  color: foreground,
                  fontSize: height * 0.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(width: height * 0.15),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a counter's value once it's above 0; tap to show it big.
  Widget _counterButton(CounterValue cv, double barHeight) {
    final active = _shownCounter?.counter == cv.counter;
    final diameter = (barHeight * 0.75).clamp(36.0, 48.0);
    final foreground = active ? widget.color : Colors.white;
    return GestureDetector(
      key: ValueKey(('counter', cv.counter.name)),
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleCounter(cv.counter),
      child: Container(
        height: barHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: Container(
          height: diameter,
          constraints: BoxConstraints(minWidth: diameter),
          padding: EdgeInsets.symmetric(horizontal: cv.value > 0 ? 10 : 0),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: active ? Colors.white : const Color(0x26000000),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                counterIcons[cv.counter],
                size: diameter * 0.5,
                color: foreground,
              ),
              if (cv.value > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '${cv.value}',
                  style: TextStyle(
                    color: foreground,
                    fontSize: diameter * 0.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _deltaText() {
    return AnimatedOpacity(
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
    );
  }

  /// Opens and closes damage mode. Filled while open, in the same spot either
  /// way, so the button that opened it is the one that closes it.
  Widget _swordsButton(double barHeight) {
    final active = _damageMode;
    final diameter = (barHeight * 0.75).clamp(36.0, 48.0);
    return GestureDetector(
      key: const ValueKey('commander-damage'),
      behavior: HitTestBehavior.opaque,
      onTap: _toggleDamageMode,
      child: SizedBox(
        width: 64,
        height: barHeight,
        child: Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white : const Color(0x26000000),
            ),
            alignment: Alignment.center,
            child: CrossedSwords(
              size: diameter * 0.55,
              color: active ? widget.color : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Commander damage taken from one opponent, in that opponent's colour.
/// At lethal a skull appears above the number.
class _DamageArea extends StatelessWidget {
  const _DamageArea({
    super.key,
    required this.opponent,
    required this.onChange,
  });

  final Opponent opponent;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final damage = opponent.damage;
    final lethal = damage >= lethalCommanderDamage;
    final style = TextStyle(
      color: damage == 0 ? Colors.white54 : Colors.white,
      fontSize: 80,
      fontWeight: FontWeight.w600,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // An invisible "00" reserves two digits' width, so the FittedBox scales
    // 5 and 21 to the same size instead of blowing a single digit up.
    final number = Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: Text('00', style: style)),
        Text(formatNumber(damage), style: style),
      ],
    );
    return Material(
      color: opponent.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x40000000)),
      ),
      clipBehavior: Clip.antiAlias,
      child: PlusMinusArea(
        markSize: 20,
        // Adding damage takes life away, so it sounds like losing life.
        reverseSound: true,
        onChange: onChange,
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SizedBox(
              width: constraints.maxWidth * 0.5,
              height: constraints.maxHeight * (lethal ? 0.7 : 0.5),
              child: FittedBox(
                // At lethal the colour stays, so it's still clear whose
                // commander it was; a skull above the number marks it.
                child: lethal
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Skull(size: 56),
                          const SizedBox(height: 8),
                          number,
                        ],
                      )
                    : number,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
