import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
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

  /// The built-in choices for [role]. Silence isn't one: it's choosing none.
  static List<Sound> forRole(SoundRole role) => [
    for (final s in values)
      if (s.role == role) s,
  ];

  SoundChoice get choice => SoundChoice(this);
}

/// A sound that can be chosen: built in, or a file the player imported.
/// Saved by [id]: a built-in sound's name, or "file:" and the file's name.
@immutable
class SoundChoice {
  const SoundChoice(Sound this.builtIn) : file = null;
  const SoundChoice.file(String this.file) : builtIn = null;

  static const none = SoundChoice(Sound.none);

  final Sound? builtIn;

  /// An imported file's name, within [SoundFiles].
  final String? file;

  bool get isNone => builtIn == Sound.none;

  String get id => file == null ? builtIn!.name : 'file:$file';

  /// A built-in sound's name, or an imported file's name without its
  /// extension.
  String get label {
    final file = this.file;
    if (file == null) return builtIn!.label;
    final dot = file.lastIndexOf('.');
    return dot > 0 ? file.substring(0, dot) : file;
  }

  @override
  bool operator ==(Object other) => other is SoundChoice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SoundChoice($id)';
}

/// The sounds a player has imported, kept in the app's own storage so they
/// survive the original being moved or deleted.
abstract interface class SoundFiles {
  /// Where an imported sound is stored.
  String path(String file);

  /// Asks for an audio file and copies it in, returning its name, or null if
  /// the player backed out. Throws [SoundTooBig] for files over [maxBytes].
  Future<String?> import();

  /// A fresh file name to record into. Each recording gets its own, so a
  /// re-recording never plays back an earlier one the player has cached.
  String newRecording();

  /// Keeps the recording in [file] as a sound called [name], returning its
  /// file name.
  Future<String> keepRecording(String file, String name);

  /// Deletes [file], e.g. a recording that wasn't kept.
  Future<void> discard(String file);
}

/// Records from the microphone. An interface so tests can fake it.
abstract interface class SoundRecorder {
  /// Whether the app may use the microphone, asking the first time.
  Future<bool> hasPermission();

  /// Starts recording into [path].
  Future<void> start(String path);

  /// Stops recording, keeping what was recorded.
  Future<void> stop();

  /// Stops recording, throwing it away.
  Future<void> cancel();
}

/// How long a recording can be: a sound for a tap should be short.
const maxRecording = Duration(seconds: 5);

/// An imported sound over the size limit: these are meant to be short clips.
class SoundTooBig implements Exception {
  const SoundTooBig();
}

/// The largest sound file that can be imported: 2 MB.
const maxBytes = 2 * 1024 * 1024;

/// Plays a sound. An interface so tests can listen in without audio.
abstract interface class SoundPlayer {
  void play(SoundChoice sound);
}

/// Plays through the device, with one low-latency player per sound. A sound
/// played again before it finishes restarts, so rapid taps don't pile up.
class AudioSoundPlayer implements SoundPlayer {
  AudioSoundPlayer(this._files);

  final SoundFiles _files;
  final _players = <SoundChoice, AudioPlayer>{};

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
  Future<void> play(SoundChoice sound) async {
    if (sound.isNone) return;
    final player = _players[sound] ??= AudioPlayer()
      ..setAudioContext(_context)
      ..setPlayerMode(PlayerMode.lowLatency)
      ..setReleaseMode(ReleaseMode.stop);
    await player.stop();
    final file = sound.file;
    await player.play(
      file == null
          ? AssetSource(sound.builtIn!.asset)
          : DeviceFileSource(_files.path(file)),
    );
  }
}

/// Makes sound available below it: every − or + tap plays that half's sound,
/// if sound is on.
class SoundScope extends InheritedWidget {
  const SoundScope({
    super.key,
    required this.settings,
    required this.player,
    required this.files,
    required this.recorder,
    required super.child,
  });

  final AppSettings settings;
  final SoundPlayer player;
  final SoundFiles files;
  final SoundRecorder recorder;

  static SoundScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SoundScope>();

  /// Plays the sound for a tap on the − ([sign] < 0) or + half.
  static void tap(BuildContext context, int sign) =>
      _play(context, sign < 0 ? SoundRole.minus : SoundRole.plus);

  /// The light click for a change, unless vibration is turned off. It's the
  /// keyboard-key click: selectionClick (a "tick") is lighter, but many phones
  /// play it at zero strength. Android also skips it when the phone's own
  /// touch feedback is off.
  static void vibrate(BuildContext context) {
    final scope = maybeOf(context);
    if (scope != null && !scope.settings.vibration) return;
    HapticFeedback.lightImpact();
  }

  /// Plays the sound for a player being knocked out.
  static void knockedOut(BuildContext context) =>
      _play(context, SoundRole.knockedOut);

  static void _play(BuildContext context, SoundRole role) {
    final scope = maybeOf(context);
    if (scope == null || !scope.settings.soundOn) return;
    final sound = scope.settings.nextSound(role);
    if (sound != null) scope.player.play(sound);
  }

  @override
  bool updateShouldNotify(SoundScope oldWidget) =>
      settings != oldWidget.settings ||
      player != oldWidget.player ||
      files != oldWidget.files;
}
