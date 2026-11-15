import 'package:flutter/material.dart';

import '../game/game.dart';
import '../game/layouts.dart';
import '../settings/app_settings.dart';
import 'dice_roller.dart';
import 'game_menu.dart';
import 'player_panel.dart';
import 'starting_player_spin.dart';

/// The table: every player's panel facing their seat, and the menu button
/// where the panels meet.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.game, required this.settings});

  final Game game;
  final AppSettings settings;

  static const _gap = 6.0;
  static const _menuButtonSize = 48.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([game, settings]),
          builder: (context, _) {
            final seats = game.layout.seats;
            final counters = settings.counters;
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final rects = [
                  for (final seat in seats)
                    Rect.fromLTRB(
                      seat.rect.left * size.width,
                      seat.rect.top * size.height,
                      seat.rect.right * size.width,
                      seat.rect.bottom * size.height,
                    ).deflate(_gap / 2),
                ];
                final startingPlayer = game.startingPlayer;
                // The first touch anywhere on the table clears the starting
                // player's highlight (and skips the spin, if it's running).
                return Listener(
                  onPointerDown: (_) => game.clearStartingPlayer(),
                  child: Stack(
                    children: [
                      for (var i = 0; i < seats.length; i++)
                        Positioned.fromRect(
                          rect: rects[i],
                          child: RotatedBox(
                            key: ValueKey(('seat', i)),
                            quarterTurns: seats[i].quarterTurns,
                            child: PlayerPanel(
                              key: ValueKey((game.generation, i)),
                              life: game.life[i],
                              color: playerColors[i],
                              knockedOut: game.isKnockedOut(i),
                              opponents: [
                                for (final o in othersLeftToRight(
                                  game.layout,
                                  i,
                                  size,
                                ))
                                  Opponent(
                                    player: o,
                                    color: playerColors[o],
                                    damage: game.commanderDamage(
                                      to: i,
                                      from: o,
                                    ),
                                  ),
                              ],
                              commanderDamage: settings.commanderDamage,
                              counters: [
                                for (final c in counters)
                                  CounterValue(c, game.counter(c, i)),
                              ],
                              onCounterChange: (c, delta) =>
                                  game.changeCounter(c, i, delta),
                              onLifeChange: (delta) =>
                                  game.changeLife(i, delta),
                              onDamageChange: (from, delta) =>
                                  game.changeCommanderDamage(
                                    to: i,
                                    from: from,
                                    delta: delta,
                                  ),
                            ),
                          ),
                        ),
                      // Where the panels meet: the ⚙, and the dice beside it
                      // when they're turned on.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: (size.height - _menuButtonSize) / 2,
                        height: _menuButtonSize,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox.square(
                              dimension: _menuButtonSize,
                              child: GameMenuButton(
                                game: game,
                                settings: settings,
                              ),
                            ),
                            if (settings.dice) ...[
                              const SizedBox(width: 8),
                              SizedBox.square(
                                dimension: _menuButtonSize,
                                child: DiceButton(settings: settings),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (startingPlayer != null)
                        StartingPlayerSpin(
                          // A new game restarts the spin.
                          key: ValueKey(('starting-player', game.generation)),
                          seatRects: rects,
                          chosen: startingPlayer,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
