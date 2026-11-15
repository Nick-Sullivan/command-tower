import 'package:command_tower/game/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts with 4 players on 40 life', () {
    final game = Game();
    expect(game.playerCount, 4);
    expect(game.life, [40, 40, 40, 40]);
  });

  test('changes one player\'s life, which can go below zero', () {
    final game = Game(playerCount: 2, startingLife: 20);
    game.changeLife(1, -25);
    expect(game.life, [20, -5]);
  });

  test('a new game resets life and moves to the next generation', () {
    final game = Game();
    final before = game.generation;
    game.changeLife(0, -3);
    game.newGame(playerCount: 3, layoutIndex: 1, startingLife: 20);
    expect(game.life, [20, 20, 20]);
    expect(game.layoutIndex, 1);
    expect(game.generation, before + 1);
  });
}
