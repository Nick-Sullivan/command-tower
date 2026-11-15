import 'package:flutter/material.dart';

import '../game/dice.dart';
import '../game/game.dart';
import '../widgets/counter_icon.dart';
import '../widgets/crossed_swords.dart';
import '../widgets/turn_stats.dart';
import 'app_settings.dart';

/// The turn timer first, with each player's turn times; then a chip per
/// other thing on the table, alphabetically. Selected ones appear on every
/// panel (or, for dice, as a button by the ⚙). Changes apply straight away
/// and never reset the game.
class TrackingSettings extends StatelessWidget {
  const TrackingSettings({
    super.key,
    required this.settings,
    required this.game,
  });

  final AppSettings settings;
  final Game game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final on = settings.counters;
        final chips = <(String, Widget)>[
          (
            'Commander damage',
            FilterChip(
              avatar: Builder(
                builder: (context) => CrossedSwords(
                  size: 18,
                  color: IconTheme.of(context).color ?? Colors.black,
                ),
              ),
              showCheckmark: false,
              label: const Text('Commander damage'),
              selected: settings.commanderDamage,
              onSelected: settings.setCommanderDamage,
            ),
          ),
          ('Dice', _Dice(settings: settings)),
          for (final c in Counter.values)
            (
              c.label,
              FilterChip(
                avatar: Icon(counterIcons[c], size: 18),
                showCheckmark: false,
                label: Text(c.label),
                selected: on.contains(c),
                onSelected: (selected) => settings.setCounter(c, selected),
              ),
            ),
        ]..sort((a, b) => a.$1.compareTo(b.$1));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TurnTimer(settings: settings, game: game),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final (_, chip) in chips) chip],
            ),
          ],
        );
      },
    );
  }
}

/// The Turn timer chip. Once it's on, it opens out into a box holding the
/// chip and, right under it, each player's turn times.
class _TurnTimer extends StatelessWidget {
  const _TurnTimer({required this.settings, required this.game});

  final AppSettings settings;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      avatar: const Icon(Icons.timer, size: 18),
      showCheckmark: false,
      label: const Text('Turn timer'),
      selected: settings.turnTimer,
      onSelected: settings.setTurnTimer,
    );
    if (!settings.turnTimer) return chip;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chip,
          TurnStats(game: game),
        ],
      ),
    );
  }
}

/// The Dice chip. Once it's on, it opens out in place into a box holding
/// the chip and, beside it, which dice the roller offers.
class _Dice extends StatelessWidget {
  const _Dice({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      avatar: const Icon(Icons.casino, size: 18),
      showCheckmark: false,
      label: const Text('Dice'),
      selected: settings.dice,
      onSelected: settings.setDice,
    );
    if (!settings.dice) return chip;
    final shown = settings.diceShown;
    return Container(
      key: const ValueKey('dice-shown'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip,
          for (final die in Die.values)
            FilterChip(
              showCheckmark: false,
              label: Text(die.label),
              selected: shown.contains(die),
              // The last die shown can't be turned off, but it still looks
              // like any other selected die rather than greyed out.
              onSelected: (selected) => settings.setDieShown(die, selected),
            ),
        ],
      ),
    );
  }
}
