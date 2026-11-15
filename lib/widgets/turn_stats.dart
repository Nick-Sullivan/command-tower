import 'package:flutter/material.dart';

import '../game/game.dart';
import 'player_panel.dart';
import 'turn_clock.dart';

/// Each player's turns this game: how many, their total time and their
/// average, one row per player marked with their colour. The menu pauses the
/// clock, so the figures hold still while they're read.
class TurnStats extends StatelessWidget {
  const TurnStats({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final theme = Theme.of(context);
        final players = [for (var p = 0; p < game.playerCount; p++) p];
        // Nothing to show until the turn timer has run this game.
        if (players.every((p) => game.turnCount(p) == 0)) {
          return const SizedBox.shrink();
        }
        final header = theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        final cell = theme.textTheme.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        Widget right(String text, TextStyle? style) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(text, style: style, textAlign: TextAlign.right),
        );
        return Table(
          key: const ValueKey('turn-stats'),
          columnWidths: const {0: FixedColumnWidth(32)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                const SizedBox(),
                right('Turns', header),
                right('Total', header),
                right('Average', header),
              ],
            ),
            for (final p in players)
              TableRow(
                key: ValueKey(('turn-stats', p)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: playerColors[p],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  right('${game.turnCount(p)}', cell),
                  right(TurnClock.format(game.turnTotal(p)), cell),
                  right(
                    game.turnCount(p) == 0
                        ? '–'
                        : TurnClock.format(
                            game.turnTotal(p) ~/ game.turnCount(p),
                          ),
                    cell,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
