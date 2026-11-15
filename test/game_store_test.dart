import 'package:command_tower/game/game.dart';
import 'package:command_tower/game/game_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameStore> _storeWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return GameStore.open();
}

void main() {
  test('with nothing saved, loads a fresh default game', () async {
    final game = (await _storeWith({})).load();
    expect(game.playerCount, 4);
    expect(game.life, [40, 40, 40, 40]);
  });

  test('every change is saved and comes back on the next launch', () async {
    final store = await _storeWith({});
    final game = store.load();
    store.autosave(game);
    game.newGame(playerCount: 3, layoutIndex: 1, startingLife: 20);
    game.changeLife(2, -7);

    // A new store over the same storage is what the next launch sees.
    final restored = (await GameStore.open()).load();
    expect(restored.playerCount, 3);
    expect(restored.layoutIndex, 1);
    expect(restored.startingLife, 20);
    expect(restored.life, [20, 20, 13]);
  });

  test('a corrupt or unplayable save falls back to a fresh game', () async {
    for (final saved in [
      'not json',
      '[]',
      '{"playerCount": 9, "layoutIndex": 0, "startingLife": 40, '
          '"life": [40, 40, 40, 40, 40, 40, 40, 40, 40]}',
      '{"playerCount": 2, "layoutIndex": 5, "startingLife": 40, '
          '"life": [40, 40]}',
      '{"playerCount": 2, "layoutIndex": 0, "startingLife": 40, '
          '"life": [40]}',
    ]) {
      final game = (await _storeWith({'game': saved})).load();
      expect(game.life, [40, 40, 40, 40], reason: saved);
    }
  });

  test('round-trips through JSON', () {
    final game = Game(playerCount: 5, layoutIndex: 1, startingLife: 30)
      ..changeLife(0, -12)
      ..changeLife(4, 3);
    final copy = Game.fromJson(game.toJson())!;
    expect(copy.playerCount, 5);
    expect(copy.layoutIndex, 1);
    expect(copy.startingLife, 30);
    expect(copy.life, [18, 30, 30, 30, 33]);
  });
}
