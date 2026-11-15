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

  test(
    'commander damage also comes off life, and corrections give it back',
    () {
      final game = Game();
      expect(game.changeCommanderDamage(to: 2, from: 0, delta: 6), 6);
      expect(game.commanderDamage(to: 2, from: 0), 6);
      expect(game.life[2], 34);

      expect(game.changeCommanderDamage(to: 2, from: 0, delta: -1), -1);
      expect(game.commanderDamage(to: 2, from: 0), 5);
      expect(game.life[2], 35);

      // Damage from different commanders is tracked separately.
      game.changeCommanderDamage(to: 2, from: 1, delta: 3);
      expect(game.commanderDamage(to: 2, from: 0), 5);
      expect(game.commanderDamage(to: 2, from: 1), 3);
      expect(game.commanderDamage(to: 1, from: 2), 0);
      expect(game.life, [40, 40, 32, 40]);
    },
  );

  test('commander damage stops at 0 without giving back extra life', () {
    final game = Game();
    game.changeCommanderDamage(to: 0, from: 1, delta: 4);
    expect(game.changeCommanderDamage(to: 0, from: 1, delta: -10), -4);
    expect(game.commanderDamage(to: 0, from: 1), 0);
    expect(game.life[0], 40);
    expect(game.changeCommanderDamage(to: 0, from: 1, delta: -1), 0);
    expect(game.life[0], 40);
  });

  test('knocked out at 0 life or lethal damage from one commander', () {
    final game = Game(playerCount: 3);
    expect(game.isKnockedOut(0), isFalse);

    game.changeLife(0, -40);
    expect(game.isKnockedOut(0), isTrue);
    game.changeLife(0, 1);
    expect(game.isKnockedOut(0), isFalse);

    // 20 from each of two commanders isn't lethal; 21 from one is, even
    // with life left.
    game.changeLife(1, 100);
    game.changeCommanderDamage(to: 1, from: 0, delta: 20);
    game.changeCommanderDamage(to: 1, from: 2, delta: 20);
    expect(game.isKnockedOut(1), isFalse);
    game.changeCommanderDamage(to: 1, from: 2, delta: 1);
    expect(game.life[1], 99);
    expect(game.isKnockedOut(1), isTrue);
  });

  test('counters change per player and never go below 0', () {
    final game = Game();
    game.changeCounter(Counter.poison, 1, 3);
    game.changeCounter(Counter.energy, 1, 2);
    expect(game.counter(Counter.poison, 1), 3);
    expect(game.counter(Counter.energy, 1), 2);
    expect(game.counter(Counter.poison, 0), 0);
    game.changeCounter(Counter.poison, 1, -5);
    expect(game.counter(Counter.poison, 1), 0);
    // Counters never touch life.
    expect(game.life, [40, 40, 40, 40]);
  });

  test('10 poison knocks a player out', () {
    final game = Game();
    game.changeCounter(Counter.poison, 2, 9);
    expect(game.isKnockedOut(2), isFalse);
    game.changeCounter(Counter.poison, 2, 1);
    expect(game.isKnockedOut(2), isTrue);
    // Other counters have no lethal value.
    game.changeCounter(Counter.experience, 3, 50);
    expect(game.isKnockedOut(3), isFalse);
  });

  test('a new game resets life and moves to the next generation', () {
    final game = Game();
    final before = game.generation;
    game.changeLife(0, -3);
    game.changeCommanderDamage(to: 0, from: 1, delta: 5);
    game.changeCounter(Counter.poison, 0, 4);
    game.newGame(playerCount: 3, layoutIndex: 1, startingLife: 20);
    expect(game.counter(Counter.poison, 0), 0);
    expect(game.life, [20, 20, 20]);
    expect(game.commanderDamage(to: 0, from: 1), 0);
    expect(game.layoutIndex, 1);
    expect(game.generation, before + 1);
  });
}
