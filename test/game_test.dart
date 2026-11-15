import 'package:clock/clock.dart';
import 'package:command_tower/game/game.dart';
import 'package:command_tower/widgets/turn_clock.dart';
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

  test('progress is any change since the start', () {
    for (final change in <void Function(Game)>[
      (g) => g.changeLife(0, -1),
      (g) => g.changeCommanderDamage(to: 1, from: 0, delta: 1),
      (g) => g.changeCounter(Counter.energy, 2, 1),
    ]) {
      final game = Game();
      expect(game.hasProgress, isFalse);
      change(game);
      expect(game.hasProgress, isTrue);
    }
    // Back to where it started counts as no progress.
    final game = Game()
      ..changeLife(0, -1)
      ..changeLife(0, 1);
    expect(game.hasProgress, isFalse);
  });

  test('a starting player lasts until cleared or the next new game', () {
    final game = Game();
    expect(game.startingPlayer, isNull);
    game.newGame(
      playerCount: 3,
      layoutIndex: 0,
      startingLife: 40,
      startingPlayer: 2,
    );
    expect(game.startingPlayer, 2);
    game.clearStartingPlayer();
    expect(game.startingPlayer, isNull);

    game.newGame(
      playerCount: 3,
      layoutIndex: 0,
      startingLife: 40,
      startingPlayer: 1,
    );
    game.newGame(playerCount: 3, layoutIndex: 0, startingLife: 40);
    expect(game.startingPlayer, isNull);
  });

  test('turn time reads as m:ss, or h:mm:ss past an hour', () {
    expect(TurnClock.format(const Duration(seconds: 7)), '0:07');
    expect(TurnClock.format(const Duration(minutes: 12, seconds: 30)), '12:30');
    expect(
      TurnClock.format(const Duration(hours: 1, minutes: 2, seconds: 5)),
      '1:02:05',
    );
  });

  group('turns', () {
    test('with nobody picked, whoever begins the first turn goes first', () {
      var now = DateTime(2026, 1, 1, 20);
      withClock(Clock(() => now), () {
        final game = Game()..startTurns();
        expect(game.turnsStarted, isTrue);
        expect(game.turnWaiting, isTrue);
        expect(game.turnPlayer, isNull);
        now = now.add(const Duration(minutes: 2));
        expect(game.turnElapsed, Duration.zero);
        game.beginTurn(2);
        expect(game.turnWaiting, isFalse);
        expect(game.turnPlayer, 2);
        expect(game.turnStarted, now);
        expect(game.turnCount(2), 1);
        // Only the first turn is begun this way.
        game.beginTurn(0);
        expect(game.turnPlayer, 2);
      });
    });

    test('with a player picked, only they can begin the first turn', () {
      final game = Game()
        ..newGame(
          playerCount: 4,
          layoutIndex: 0,
          startingLife: 40,
          startingPlayer: 2,
        )
        ..startTurns();
      expect(game.turnPlayer, 2);
      expect(game.turnWaiting, isTrue);
      // Still waiting for them after a save and restore.
      expect(Game.fromJson(game.toJson())!.turnWaiting, isTrue);
      game.beginTurn(1);
      expect(game.turnWaiting, isTrue);
      game.beginTurn(2);
      expect(game.turnWaiting, isFalse);

      // A new game stops turns until they're started again.
      game.newGame(playerCount: 4, layoutIndex: 0, startingLife: 40);
      expect(game.turnsStarted, isFalse);
      expect(game.turnPlayer, isNull);
    });

    test('pass clockwise, skipping knocked-out players', () {
      final game = Game()
        ..startTurns()
        ..beginTurn(0);
      game.endTurn();
      expect(game.turnPlayer, 1);
      game.changeLife(2, -40);
      game.endTurn();
      expect(game.turnPlayer, 3);
      game.endTurn();
      expect(game.turnPlayer, 0);
    });

    test('each turn restarts the time', () {
      withClock(Clock.fixed(DateTime(2026, 1, 1, 20)), () {
        final game = Game()
          ..startTurns()
          ..beginTurn(0);
        expect(game.turnStarted, DateTime(2026, 1, 1, 20));
      });
      withClock(Clock.fixed(DateTime(2026, 1, 1, 20, 3)), () {
        final game = Game()
          ..startTurns()
          ..beginTurn(0);
        game.endTurn();
        expect(game.turnStarted, DateTime(2026, 1, 1, 20, 3));
      });
    });

    test('pausing stops the turn time until it resumes', () {
      var now = DateTime(2026, 1, 1, 20);
      withClock(Clock(() => now), () {
        final game = Game()
          ..startTurns()
          ..beginTurn(0);
        now = now.add(const Duration(seconds: 30));
        game.pauseTurn();
        now = now.add(const Duration(minutes: 5));
        expect(game.turnElapsed, const Duration(seconds: 30));
        game.resumeTurn();
        now = now.add(const Duration(seconds: 10));
        expect(game.turnElapsed, const Duration(seconds: 40));
      });
    });

    test('counts each player\'s turns and their time', () {
      var now = DateTime(2026, 1, 1, 20);
      withClock(Clock(() => now), () {
        final game = Game(playerCount: 2, layoutIndex: 0)
          ..startTurns()
          ..beginTurn(0);
        now = now.add(const Duration(seconds: 30));
        game.endTurn();
        now = now.add(const Duration(seconds: 50));
        game.endTurn();
        now = now.add(const Duration(seconds: 10));
        // Player 0: 30s done, plus 10s in progress; player 1: one of 50s.
        expect(game.turnCount(0), 2);
        expect(game.turnTotal(0), const Duration(seconds: 40));
        expect(game.turnCount(1), 1);
        expect(game.turnTotal(1), const Duration(seconds: 50));

        final copy = Game.fromJson(game.toJson())!;
        expect(copy.turnCount(1), 1);
        expect(copy.turnTotal(1), const Duration(seconds: 50));

        game.newGame(playerCount: 2, layoutIndex: 0, startingLife: 40);
        expect(game.turnCount(0), 0);
        expect(game.turnTotal(1), Duration.zero);
      });
    });

    test('the turn in progress is saved with the game', () {
      final game = Game()
        ..startTurns()
        ..beginTurn(0)
        ..endTurn();
      final copy = Game.fromJson(game.toJson())!;
      expect(copy.turnPlayer, 1);
      expect(copy.turnStarted, game.turnStarted!.copyWith(microsecond: 0));
    });
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
