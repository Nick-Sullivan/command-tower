import 'dart:math';

import 'package:flutter/foundation.dart';

import 'layouts.dart';

/// Commander damage from a single commander that knocks a player out.
const lethalCommanderDamage = 21;

class Game extends ChangeNotifier {
  Game({int playerCount = 4, int layoutIndex = 0, int startingLife = 40}) {
    _start(playerCount, layoutIndex, startingLife);
  }

  late int _playerCount;
  late int _layoutIndex;
  late int _startingLife;
  late List<int> _life;

  /// `_commanderDamage[victim][source]`: damage [victim] has taken from
  /// [source]'s commander. The diagonal is always 0.
  late List<List<int>> _commanderDamage;
  int _generation = -1;

  int get playerCount => _playerCount;
  int get layoutIndex => _layoutIndex;
  int get startingLife => _startingLife;
  List<int> get life => List.unmodifiable(_life);

  /// Increases with every new game, so per-game widget state can reset.
  int get generation => _generation;

  TableLayout get layout => tableLayouts[_playerCount]![_layoutIndex];

  int commanderDamage({required int to, required int from}) =>
      _commanderDamage[to][from];

  /// Whether [player] would normally have lost: 0 or less life, or lethal
  /// damage from one commander. Only shown, never enforced — some cards let
  /// a player keep going.
  bool isKnockedOut(int player) =>
      _life[player] <= 0 ||
      _commanderDamage[player].any((d) => d >= lethalCommanderDamage);

  void changeLife(int player, int delta) {
    _life[player] += delta;
    notifyListeners();
  }

  /// Changes the damage [to] has taken from [from]'s commander, never below 0.
  /// Life moves the opposite way by the same amount, so damage is entered
  /// once. Returns how much the damage actually changed.
  int changeCommanderDamage({
    required int to,
    required int from,
    required int delta,
  }) {
    assert(to != from);
    final before = _commanderDamage[to][from];
    final after = max(0, before + delta);
    if (after == before) return 0;
    _commanderDamage[to][from] = after;
    _life[to] -= after - before;
    notifyListeners();
    return after - before;
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
    'commanderDamage': _commanderDamage,
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
        !_isIntList(life, playerCount)) {
      return null;
    }
    final layouts = tableLayouts[playerCount];
    if (layouts == null || layoutIndex < 0 || layoutIndex >= layouts.length) {
      return null;
    }
    final game = Game(
      playerCount: playerCount,
      layoutIndex: layoutIndex,
      startingLife: startingLife,
    ).._life = (life as List).cast<int>().toList();

    // Saves from before commander damage existed simply have none.
    final damage = json['commanderDamage'];
    if (damage != null) {
      if (damage is! List ||
          damage.length != playerCount ||
          damage.any((row) => !_isIntList(row, playerCount))) {
        return null;
      }
      game._commanderDamage = [
        for (final row in damage) (row as List).cast<int>().toList(),
      ];
    }
    return game;
  }

  static bool _isIntList(Object? value, int length) =>
      value is List && value.length == length && value.every((v) => v is int);

  void _start(int playerCount, int layoutIndex, int startingLife) {
    assert(tableLayouts.containsKey(playerCount));
    assert(layoutIndex < tableLayouts[playerCount]!.length);
    _playerCount = playerCount;
    _layoutIndex = layoutIndex;
    _startingLife = startingLife;
    _life = List.filled(playerCount, startingLife);
    _commanderDamage = [
      for (var i = 0; i < playerCount; i++) List.filled(playerCount, 0),
    ];
    _generation++;
  }
}
