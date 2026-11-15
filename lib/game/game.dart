import 'package:flutter/foundation.dart';

import 'layouts.dart';

class Game extends ChangeNotifier {
  Game({int playerCount = 4, int layoutIndex = 0, int startingLife = 40}) {
    _start(playerCount, layoutIndex, startingLife);
  }

  late int _playerCount;
  late int _layoutIndex;
  late int _startingLife;
  late List<int> _life;
  int _generation = -1;

  int get playerCount => _playerCount;
  int get layoutIndex => _layoutIndex;
  int get startingLife => _startingLife;
  List<int> get life => List.unmodifiable(_life);

  /// Increases with every new game, so per-game widget state can reset.
  int get generation => _generation;

  TableLayout get layout => tableLayouts[_playerCount]![_layoutIndex];

  void changeLife(int player, int delta) {
    _life[player] += delta;
    notifyListeners();
  }

  void newGame({
    required int playerCount,
    required int layoutIndex,
    required int startingLife,
  }) {
    _start(playerCount, layoutIndex, startingLife);
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
    'playerCount': _playerCount,
    'layoutIndex': _layoutIndex,
    'startingLife': _startingLife,
    'life': _life,
  };

  /// Restores a saved game, or returns null if [json] isn't one this version
  /// can play — e.g. a layout that no longer exists.
  static Game? fromJson(Map<String, Object?> json) {
    final playerCount = json['playerCount'];
    final layoutIndex = json['layoutIndex'];
    final startingLife = json['startingLife'];
    final life = json['life'];
    if (playerCount is! int ||
        layoutIndex is! int ||
        startingLife is! int ||
        life is! List ||
        life.length != playerCount ||
        life.any((l) => l is! int)) {
      return null;
    }
    final layouts = tableLayouts[playerCount];
    if (layouts == null || layoutIndex < 0 || layoutIndex >= layouts.length) {
      return null;
    }
    return Game(
      playerCount: playerCount,
      layoutIndex: layoutIndex,
      startingLife: startingLife,
    ).._life = life.cast<int>().toList();
  }

  void _start(int playerCount, int layoutIndex, int startingLife) {
    assert(tableLayouts.containsKey(playerCount));
    assert(layoutIndex < tableLayouts[playerCount]!.length);
    _playerCount = playerCount;
    _layoutIndex = layoutIndex;
    _startingLife = startingLife;
    _life = List.filled(playerCount, startingLife);
    _generation++;
  }
}
