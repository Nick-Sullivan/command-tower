import 'package:flutter/material.dart';

import '../game/game.dart';
import '../game/layouts.dart';
import '../settings/app_settings.dart';
import 'game_menu.dart';
import 'player_panel.dart';

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
                return Stack(
                  children: [
                    for (var i = 0; i < seats.length; i++)
                      Positioned.fromRect(
                        rect: Rect.fromLTRB(
                          seats[i].rect.left * size.width,
                          seats[i].rect.top * size.height,
                          seats[i].rect.right * size.width,
                          seats[i].rect.bottom * size.height,
                        ).deflate(_gap / 2),
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
                                  damage: game.commanderDamage(to: i, from: o),
                                ),
                            ],
                            commanderDamage: settings.commanderDamage,
                            counters: [
                              for (final c in counters)
                                CounterValue(c, game.counter(c, i)),
                            ],
                            onCounterChange: (c, delta) =>
                                game.changeCounter(c, i, delta),
                            onLifeChange: (delta) => game.changeLife(i, delta),
                            onDamageChange: (from, delta) =>
                                game.changeCommanderDamage(
                                  to: i,
                                  from: from,
                                  delta: delta,
                                ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: (size.width - _menuButtonSize) / 2,
                      top: (size.height - _menuButtonSize) / 2,
                      width: _menuButtonSize,
                      height: _menuButtonSize,
                      child: GameMenuButton(game: game, settings: settings),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
