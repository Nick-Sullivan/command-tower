import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';

/// Keeps the current game on the device, so closing the app or a crash
/// never loses it.
class GameStore {
  GameStore(this._prefs);

  static const _key = 'game';

  final SharedPreferences _prefs;

  static Future<GameStore> open() async =>
      GameStore(await SharedPreferences.getInstance());

  /// The saved game, or a fresh default one if there's none or it can't be
  /// read.
  Game load() {
    final saved = _prefs.getString(_key);
    if (saved == null) return Game();
    try {
      final json = jsonDecode(saved);
      if (json is Map<String, Object?>) return Game.fromJson(json) ?? Game();
    } on FormatException {
      // Fall through to a fresh game.
    }
    return Game();
  }

  /// Saves [game] now and after every change to it.
  void autosave(Game game) {
    void save() => _prefs.setString(_key, jsonEncode(game.toJson()));
    save();
    game.addListener(save);
  }
}
