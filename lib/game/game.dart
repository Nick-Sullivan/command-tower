import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'counters.dart';
import 'layouts.dart';

export 'counters.dart';

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

  /// Every counter's value per player, whether or not it's turned on, so
  /// turning one off and on again mid-game loses nothing.
  late Map<Counter, List<int>> _counters;
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

  int counter(Counter counter, int player) => _counters[counter]![player];

  /// Whether [player] would normally have lost: 0 or less life, lethal
  /// damage from one commander, or a lethal counter such as 10 poison. Only
  /// shown, never enforced — some cards let a player keep going.
  bool isKnockedOut(int player) =>
      _life[player] <= 0 ||
      _commanderDamage[player].any((d) => d >= lethalCommanderDamage) ||
      Counter.values.any(
        (c) => c.lethal != null && _counters[c]![player] >= c.lethal!,
      );

  /// Changes [player]'s [counter] by [delta], never below 0.
  void changeCounter(Counter counter, int player, int delta) {
    final values = _counters[counter]!;
    final after = max(0, values[player] + delta);
    if (after == values[player]) return;
    values[player] = after;
    notifyListeners();
  }

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

  /// Whether anything has happened since the game started: any life, commander
  /// damage or counter changed. A new game would lose it.
  bool get hasProgress =>
      _life.any((l) => l != _startingLife) ||
      _commanderDamage.any((row) => row.any((d) => d != 0)) ||
      _counters.values.any((values) => values.any((v) => v != 0));

  /// Who was picked to go first, while it's still being shown; cleared once
  /// anyone touches the table. Not saved: it only matters at the start.
  int? get startingPlayer => _startingPlayer;
  int? _startingPlayer;

  void clearStartingPlayer() {
    if (_startingPlayer == null) return;
    _startingPlayer = null;
    notifyListeners();
  }

  /// Whose turn it is, for the turn timer; null until the timer starts.
  int? get turnPlayer => _turnPlayer;
  int? _turnPlayer;

  /// When the current turn began.
  DateTime? get turnStarted => _turnStarted;
  DateTime? _turnStarted;

  /// When the turn's time was paused (while the menu is open), or null while
  /// it's running.
  DateTime? get turnPaused => _turnPaused;
  DateTime? _turnPaused;

  /// How long the current turn has run, not counting pauses.
  Duration get turnElapsed {
    final started = _turnStarted;
    if (started == null) return Duration.zero;
    final elapsed = (_turnPaused ?? clock.now()).difference(started);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// Freezes the turn's time, e.g. while the menu is open.
  void pauseTurn() {
    if (_turnStarted == null || _turnPaused != null) return;
    _turnPaused = clock.now();
    notifyListeners();
  }

  /// Carries on from where [pauseTurn] froze it.
  void resumeTurn() {
    final paused = _turnPaused;
    final started = _turnStarted;
    if (paused == null || started == null) return;
    _turnStarted = started.add(clock.now().difference(paused));
    _turnPaused = null;
    notifyListeners();
  }

  /// Each player's finished turns: how many, and their time added up.
  late List<int> _turnCounts;
  late List<Duration> _turnTotals;

  /// How many turns [player] has had, including one in progress.
  int turnCount(int player) =>
      _turnCounts[player] + (_turnPlayer == player ? 1 : 0);

  /// [player]'s time across all their turns, including one in progress.
  Duration turnTotal(int player) =>
      _turnTotals[player] +
      (_turnPlayer == player ? turnElapsed : Duration.zero);

  /// Starts taking turns, if not already: with the starting player when one
  /// was picked, otherwise the first seat.
  void startTurns() {
    if (_turnPlayer != null) return;
    _turnPlayer = _startingPlayer ?? 0;
    _turnStarted = clock.now();
    _turnPaused = null;
    notifyListeners();
  }

  /// Passes the turn clockwise (seat order) to the next player still in the
  /// game, and restarts the turn's time.
  void endTurn() {
    final current = _turnPlayer;
    if (current == null) return;
    _turnCounts[current]++;
    _turnTotals[current] += turnElapsed;
    var next = current;
    for (var i = 1; i <= _playerCount; i++) {
      final candidate = (current + i) % _playerCount;
      if (!isKnockedOut(candidate)) {
        next = candidate;
        break;
      }
    }
    _turnPlayer = next;
    _turnStarted = clock.now();
    _turnPaused = null;
    notifyListeners();
  }

  void newGame({
    required int playerCount,
    required int layoutIndex,
    required int startingLife,
    int? startingPlayer,
  }) {
    assert(startingPlayer == null || startingPlayer < playerCount);
    _start(playerCount, layoutIndex, startingLife);
    _startingPlayer = startingPlayer;
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
    'playerCount': _playerCount,
    'layoutIndex': _layoutIndex,
    'startingLife': _startingLife,
    'life': _life,
    'commanderDamage': _commanderDamage,
    'counters': {for (final c in Counter.values) c.name: _counters[c]},
    if (_turnPlayer != null) 'turnPlayer': _turnPlayer,
    if (_turnStarted != null)
      'turnStarted': _turnStarted!.millisecondsSinceEpoch,
    if (_turnPaused != null) 'turnPaused': _turnPaused!.millisecondsSinceEpoch,
    'turnCounts': _turnCounts,
    'turnTotalsMs': [for (final t in _turnTotals) t.inMilliseconds],
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

    // Likewise counters, or any counter added since the game was saved.
    final counters = json['counters'];
    if (counters != null) {
      if (counters is! Map) return null;
      for (final c in Counter.values) {
        final values = counters[c.name];
        if (values == null) continue;
        if (!_isIntList(values, playerCount)) return null;
        game._counters[c] = (values as List).cast<int>().toList();
      }
    }

    // The turn in progress, if the turn timer was running; ignored if it
    // doesn't fit this game.
    final turnPlayer = json['turnPlayer'];
    final turnStarted = json['turnStarted'];
    if (turnPlayer is int &&
        turnPlayer >= 0 &&
        turnPlayer < playerCount &&
        turnStarted is int) {
      game._turnPlayer = turnPlayer;
      game._turnStarted = DateTime.fromMillisecondsSinceEpoch(turnStarted);
      final turnPaused = json['turnPaused'];
      if (turnPaused is int) {
        game._turnPaused = DateTime.fromMillisecondsSinceEpoch(turnPaused);
      }
    }

    // Turn stats; older saves (or ones that don't fit) start from nothing.
    final counts = json['turnCounts'];
    final totals = json['turnTotalsMs'];
    if (_isIntList(counts, playerCount) && _isIntList(totals, playerCount)) {
      game._turnCounts = (counts as List).cast<int>().toList();
      game._turnTotals = [
        for (final ms in (totals as List).cast<int>())
          Duration(milliseconds: ms),
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
    _counters = {
      for (final c in Counter.values) c: List.filled(playerCount, 0),
    };
    // Turns start again (if the timer is on) once the table is showing.
    _turnPlayer = null;
    _turnStarted = null;
    _turnPaused = null;
    _turnCounts = List.filled(playerCount, 0);
    _turnTotals = List.filled(playerCount, Duration.zero);
    _generation++;
  }
}
