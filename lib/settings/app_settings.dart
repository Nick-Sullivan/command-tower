import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/counters.dart';
import '../game/dice.dart';
import '../sound/sounds.dart';

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
  static const _soundOnKey = 'soundOn';

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

  static const _diceKey = 'dice';
  static const _diceShownKey = 'diceShown';
  static const _defaultDice = {Die.coin, Die.d6, Die.d20};

  /// Whether the table has a dice button. Off by default.
  bool get dice => _prefs.getBool(_diceKey) ?? false;

  void setDice(bool on) {
    if (on == dice) return;
    _prefs.setBool(_diceKey, on);
    notifyListeners();
  }

  /// The dice the roller offers, in order. Never empty.
  List<Die> get diceShown {
    final saved = _prefs.getStringList(_diceShownKey);
    final shown = [
      for (final d in Die.values)
        if (saved == null ? _defaultDice.contains(d) : saved.contains(d.name))
          d,
    ];
    return shown.isEmpty ? [for (final d in _defaultDice) d] : shown;
  }

  /// Shows or hides [die] in the roller; the last one can't be hidden.
  void setDieShown(Die die, bool shown) {
    final current = diceShown;
    if (shown == current.contains(die)) return;
    if (!shown && current.length == 1) return;
    final next = shown
        ? [...current, die]
        : [
            for (final d in current)
              if (d != die) d,
          ];
    _prefs.setStringList(_diceShownKey, [
      for (final d in Die.values)
        if (next.contains(d)) d.name,
    ]);
    notifyListeners();
  }

  static const _randomStartingPlayerKey = 'randomStartingPlayer';

  /// Whether Start picks a random player to go first. Off by default.
  bool get randomStartingPlayer =>
      _prefs.getBool(_randomStartingPlayerKey) ?? false;

  void setRandomStartingPlayer(bool on) {
    if (on == randomStartingPlayer) return;
    _prefs.setBool(_randomStartingPlayerKey, on);
    notifyListeners();
  }

  static const _vibrationKey = 'vibration';
  static const _keepScreenOnKey = 'keepScreenOn';

  /// The light click on every change. On unless turned off.
  bool get vibration => _prefs.getBool(_vibrationKey) ?? true;

  void setVibration(bool on) {
    if (on == vibration) return;
    _prefs.setBool(_vibrationKey, on);
    notifyListeners();
  }

  /// Stops the screen sleeping mid-game. On unless turned off.
  bool get keepScreenOn => _prefs.getBool(_keepScreenOnKey) ?? true;

  void setKeepScreenOn(bool on) {
    if (on == keepScreenOn) return;
    _prefs.setBool(_keepScreenOnKey, on);
    notifyListeners();
  }

  /// Off until turned on: a phone at a quiet table shouldn't make noise.
  bool get soundOn => _prefs.getBool(_soundOnKey) ?? false;

  void setSoundOn(bool on) {
    if (on == soundOn) return;
    _prefs.setBool(_soundOnKey, on);
    notifyListeners();
  }

  static const _defaultSounds = {
    SoundRole.minus: Sound.hurt,
    SoundRole.plus: Sound.doubleCoin,
    SoundRole.knockedOut: Sound.fall,
  };

  static String _soundKey(SoundRole role) => 'sound.${role.name}';

  /// The sound chosen for [role]. A saved choice that's no longer offered
  /// for it (e.g. from an older version) falls back to the default.
  Sound sound(SoundRole role) {
    final name = _prefs.getString(_soundKey(role));
    return Sound.forRole(role).where((s) => s.name == name).firstOrNull ??
        _defaultSounds[role]!;
  }

  void setSound(SoundRole role, Sound sound) {
    assert(Sound.forRole(role).contains(sound));
    if (sound == this.sound(role)) return;
    _prefs.setString(_soundKey(role), sound.name);
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
