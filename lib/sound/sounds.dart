import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../settings/app_settings.dart';

/// When a sound plays.
enum SoundRole {
  /// Taking a hit: every tap of a − half, except on commander damage, where
  /// it's the + half (adding damage takes life away).
  minus,

  /// Healing or gaining: every tap of a + half, except on commander damage,
  /// where it's the − half.
  plus,

  /// A player being knocked out.
  knockedOut,
}

/// The built-in sounds (all CC0; see assets/sounds/LICENSE.txt), each for one
/// [SoundRole]. [none] is silence and fits any role.
enum Sound {
  none('None', null, null),
  hit('Hit', SoundRole.minus, 'hit.wav'),
  hit2('Hit 2', SoundRole.minus, 'hit_2.wav'),
  hurt('Hurt', SoundRole.minus, 'hurt.wav'),
  hurt2('Hurt 2', SoundRole.minus, 'hurt_2.wav'),
  punch('Punch', SoundRole.minus, 'punch.ogg'),
  powerDown('Power down', SoundRole.minus, 'power_down.ogg'),
  doubleCoin('Double coin', SoundRole.plus, 'double_coin.wav'),
  pickup('Pickup', SoundRole.plus, 'pickup.wav'),
  pickup2('Pickup 2', SoundRole.plus, 'pickup_2.wav'),
  bigPickup('Big pickup', SoundRole.plus, 'big_pickup.wav'),
  powerUp('Power up', SoundRole.plus, 'power_up.ogg'),
  phaserUp('Phaser up', SoundRole.plus, 'phaser_up.ogg'),
  rising('Rising', SoundRole.plus, 'rising.ogg'),
  explosion('Explosion', SoundRole.knockedOut, 'explosion.wav'),
  explosion2('Explosion 2', SoundRole.knockedOut, 'explosion_2.wav'),
  fall('Fall', SoundRole.knockedOut, 'fall.wav'),
  fall2('Fall 2', SoundRole.knockedOut, 'fall_2.wav'),
  fail('Fail', SoundRole.knockedOut, 'fail.wav');

  const Sound(this.label, this.role, this._file);

  final String label;

  /// The role this sound is offered for; null for [none].
  final SoundRole? role;
  final String? _file;

  String get asset => 'sounds/$_file';

  /// The choices for [role], silence first.
  static List<Sound> forRole(SoundRole role) => [
    none,
    for (final s in values)
      if (s.role == role) s,
  ];
}

/// Plays a sound. An interface so tests can listen in without audio.
abstract interface class SoundPlayer {
  void play(Sound sound);
}

/// Plays through the device, with one low-latency player per sound. A sound
/// played again before it finishes restarts, so rapid taps don't pile up.
class AudioSoundPlayer implements SoundPlayer {
  final _players = <Sound, AudioPlayer>{};

  /// Game sound effects: they mix with whatever else is playing and never
  /// take audio focus (which would pause someone's music on every tap). On
  /// iOS, "ambient" also respects the silent switch.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  @override
  Future<void> play(Sound sound) async {
    if (sound == Sound.none) return;
    final player = _players[sound] ??= AudioPlayer()
      ..setAudioContext(_context)
      ..setPlayerMode(PlayerMode.lowLatency)
      ..setReleaseMode(ReleaseMode.stop);
    await player.stop();
    await player.play(AssetSource(sound.asset));
  }
}

/// Makes sound available below it: every − or + tap plays that half's sound,
/// if sound is on.
class SoundScope extends InheritedWidget {
  const SoundScope({
    super.key,
    required this.settings,
    required this.player,
    required super.child,
  });

  final AppSettings settings;
  final SoundPlayer player;

  static SoundScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SoundScope>();

  /// Plays the sound for a tap on the − ([sign] < 0) or + half.
  static void tap(BuildContext context, int sign) =>
      _play(context, sign < 0 ? SoundRole.minus : SoundRole.plus);

  /// Plays the sound for a player being knocked out.
  static void knockedOut(BuildContext context) =>
      _play(context, SoundRole.knockedOut);

  static void _play(BuildContext context, SoundRole role) {
    final scope = maybeOf(context);
    if (scope == null || !scope.settings.soundOn) return;
    final sound = scope.settings.sound(role);
    if (sound != Sound.none) scope.player.play(sound);
  }

  @override
  bool updateShouldNotify(SoundScope oldWidget) =>
      settings != oldWidget.settings || player != oldWidget.player;
}
