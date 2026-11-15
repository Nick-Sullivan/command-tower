import 'package:flutter/material.dart';

import '../game/game.dart';
import '../game/layouts.dart';
import 'game_menu.dart';
import 'player_panel.dart';

/// The table: every player's panel facing their seat, and the menu button
/// where the panels meet.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.game});

  final Game game;

  static const _gap = 6.0;
  static const _menuButtonSize = 48.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            final seats = game.layout.seats;
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
                      child: GameMenuButton(game: game),
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
