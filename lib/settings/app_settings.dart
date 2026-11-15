import 'dart:math';

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

  static const _turnTimerKey = 'turnTimer';

  /// Whether the table tracks whose turn it is and for how long. Off by
  /// default.
  bool get turnTimer => _prefs.getBool(_turnTimerKey) ?? false;

  void setTurnTimer(bool on) {
    if (on == turnTimer) return;
    _prefs.setBool(_turnTimerKey, on);
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

  /// Where each role's sounds are saved. [_oldSoundKey] held the single sound
  /// a role could have before several could be chosen.
  static String _soundsKey(SoundRole role) => 'sounds.${role.name}';
  static String _oldSoundKey(SoundRole role) => 'sound.${role.name}';
  static const _importedSoundsKey = 'importedSounds';

  /// Files the player has imported, oldest first.
  List<String> get importedSounds =>
      _prefs.getStringList(_importedSoundsKey) ?? const [];

  void addImportedSound(String file) {
    if (importedSounds.contains(file)) return;
    _prefs.setStringList(_importedSoundsKey, [...importedSounds, file]);
    notifyListeners();
  }

  /// Takes away an imported sound, and from every role that had it; a role
  /// left with none is silent.
  void removeImportedSound(String file) {
    if (!importedSounds.contains(file)) return;
    final sound = SoundChoice.file(file);
    for (final role in SoundRole.values) {
      final chosen = sounds(role);
      if (!chosen.contains(sound)) continue;
      _prefs.setStringList(_soundsKey(role), [
        for (final s in chosen)
          if (s != sound) s.id,
      ]);
    }
    _prefs.setStringList(_importedSoundsKey, [
      for (final f in importedSounds)
        if (f != file) f,
    ]);
    notifyListeners();
  }

  /// What [role] can play: its built-in sounds, then every imported sound
  /// (any of which suits any role).
  List<SoundChoice> soundChoices(SoundRole role) => [
    for (final s in Sound.forRole(role)) s.choice,
    for (final f in importedSounds) SoundChoice.file(f),
  ];

  /// The sounds chosen for [role], in the order they're offered; empty for
  /// silence. Saved sounds that are no longer offered (e.g. from an older
  /// version) are dropped, and if that leaves none, it's the default.
  List<SoundChoice> sounds(SoundRole role) {
    final ids =
        _prefs.getStringList(_soundsKey(role)) ??
        [?_prefs.getString(_oldSoundKey(role))];
    if (ids.isEmpty) {
      // Never chosen: the default. Chosen as nothing: silence.
      return _prefs.containsKey(_soundsKey(role))
          ? const []
          : [_defaultSounds[role]!.choice];
    }
    // Silence used to be a sound of its own.
    if (ids.every((id) => id == Sound.none.name)) return const [];
    final chosen = [
      for (final s in soundChoices(role))
        if (ids.contains(s.id)) s,
    ];
    return chosen.isEmpty ? [_defaultSounds[role]!.choice] : chosen;
  }

  /// Adds [sound] to [role]'s sounds, or with [on] false takes it away.
  void setSound(SoundRole role, SoundChoice sound, {bool on = true}) {
    assert(soundChoices(role).contains(sound));
    final before = sounds(role);
    if (before.contains(sound) == on) return;
    final after = on ? [...before, sound] : ([...before]..remove(sound));
    _prefs.setStringList(_soundsKey(role), [for (final s in after) s.id]);
    notifyListeners();
  }

  final _random = Random();
  final _lastPlayed = <SoundRole, SoundChoice>{};

  /// One of [role]'s sounds to play, at random, never the same one twice in
  /// a row; null if it has none.
  SoundChoice? nextSound(SoundRole role) {
    final chosen = sounds(role);
    if (chosen.isEmpty) return null;
    final fresh = chosen.length > 1
        ? [
            for (final s in chosen)
              if (s != _lastPlayed[role]) s,
          ]
        : chosen;
    return _lastPlayed[role] = fresh[_random.nextInt(fresh.length)];
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
