import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game.dart';
import 'crossed_swords.dart';
import 'plus_minus_area.dart';
import 'skull.dart';

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

/// One player's panel, laid out upright for them; wrap it in a [RotatedBox]
/// to face their seat.
///
/// It shows their life total, or — after tapping the swords — the commander
/// damage they've taken from each opponent, with opponents placed left to
/// right as they sit around the table.
class PlayerPanel extends StatefulWidget {
  const PlayerPanel({
    super.key,
    required this.life,
    required this.color,
    required this.opponents,
    required this.onLifeChange,
    required this.onDamageChange,
  });

  final int life;
  final Color color;

  /// Ordered left to right from this player's seat.
  final List<Opponent> opponents;
  final ValueChanged<int> onLifeChange;

  /// Changes damage taken from opponent `from` by `delta`; returns how much
  /// it actually changed (damage can't go below 0).
  final int Function(int from, int delta) onDamageChange;

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
  static const _deltaVisibleFor = Duration(seconds: 2);

  bool _damageMode = false;
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
  }

  void _toggleDamageMode() {
    HapticFeedback.lightImpact();
    setState(() => _damageMode = !_damageMode);
  }

  @override
  void dispose() {
    _deltaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.color,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final barHeight = (size.height * 0.22).clamp(44.0, 72.0);
          return _damageMode
              ? _damageView(size, barHeight)
              : _lifeView(size, barHeight);
        },
      ),
    );
  }

  Widget _lifeView(Size size, double barHeight) {
    return Stack(
      children: [
        PlusMinusArea(
          onChange: _changeLife,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: size.height * 0.14,
                  width: size.width * 0.3,
                  child: _deltaText(),
                ),
                SizedBox(
                  height: size.height * 0.5,
                  width: size.width * 0.6,
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
          child: Center(child: _swordsButton(barHeight)),
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
        SizedBox(
          height: barHeight,
          child: Row(
            children: [
              const Spacer(),
              _swordsButton(barHeight),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
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
              ),
            ],
          ),
        ),
      ],
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
