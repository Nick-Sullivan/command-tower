import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/counters.dart';

/// Choices that outlast a single game, from the Tracking tab. Every change is
/// saved straight away.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    final saved = _prefs.getStringList(_countersKey) ?? const [];
    _counters = {
      for (final c in Counter.values)
        if (saved.contains(c.name)) c,
    };
  }

  static const _countersKey = 'counters';
  static const _commanderDamageKey = 'commanderDamage';

  final SharedPreferences _prefs;
  late Set<Counter> _counters;

  static Future<AppSettings> open() async =>
      AppSettings(await SharedPreferences.getInstance());

  /// Whether panels have the swords for commander damage. On unless turned
  /// off: it's central to Commander.
  bool get commanderDamage => _prefs.getBool(_commanderDamageKey) ?? true;

  void setCommanderDamage(bool on) {
    if (on == commanderDamage) return;
    _prefs.setBool(_commanderDamageKey, on);
    notifyListeners();
  }

  /// Counters turned on for every player, in a fixed order.
  List<Counter> get counters => [
    for (final c in Counter.values)
      if (_counters.contains(c)) c,
  ];

  void setCounter(Counter counter, bool on) {
    if (on ? !_counters.add(counter) : !_counters.remove(counter)) return;
    _prefs.setStringList(_countersKey, [for (final c in counters) c.name]);
    notifyListeners();
  }
}
