import 'dart:io';

import 'package:command_tower/game/counters.dart';
import 'package:command_tower/sound/sounds.dart';
import 'package:command_tower/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('no counters until turned on, and they stay on next launch', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.open();
    expect(settings.counters, isEmpty);

    // Turned on in any order, but always listed alphabetically.
    settings.setCounter(Counter.poison, true);
    settings.setCounter(Counter.energy, true);
    expect(settings.counters, [Counter.energy, Counter.poison]);

    settings.setCounter(Counter.energy, false);
    final relaunched = await AppSettings.open();
    expect(relaunched.counters, [Counter.poison]);
  });

  test('counters are declared alphabetically', () {
    final labels = [for (final c in Counter.values) c.label];
    expect(labels, [...labels]..sort());
  });

  test('sound is off by default; choices are remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.open();
    expect(settings.soundOn, isFalse);
    expect(settings.sound(SoundRole.minus), Sound.hurt);
    expect(settings.sound(SoundRole.plus), Sound.doubleCoin);
    expect(settings.sound(SoundRole.knockedOut), Sound.fall);

    settings.setSoundOn(true);
    settings.setSound(SoundRole.minus, Sound.none);
    settings.setSound(SoundRole.plus, Sound.phaserUp);
    final relaunched = await AppSettings.open();
    expect(relaunched.soundOn, isTrue);
    expect(relaunched.sound(SoundRole.minus), Sound.none);
    expect(relaunched.sound(SoundRole.plus), Sound.phaserUp);
  });

  test('a saved sound that is no longer offered falls back to default', () {
    // e.g. 'thud' from the first version, or a sound from another role.
    SharedPreferences.setMockInitialValues({
      'sound.minus': 'thud',
      'sound.plus': 'youLose',
    });
    return AppSettings.open().then((settings) {
      expect(settings.sound(SoundRole.minus), Sound.hurt);
      expect(settings.sound(SoundRole.plus), Sound.doubleCoin);
    });
  });

  test('every role has choices, and every sound its file', () {
    for (final role in SoundRole.values) {
      expect(Sound.forRole(role).length, greaterThan(1), reason: role.name);
    }
    for (final sound in Sound.values) {
      if (sound == Sound.none) continue;
      expect(sound.role, isNotNull);
    }
  });

  test('every built-in sound has its file', () {
    for (final sound in Sound.values) {
      if (sound == Sound.none) continue;
      expect(
        File('assets/${sound.asset}').existsSync(),
        isTrue,
        reason: sound.name,
      );
    }
  });

  test('commander damage is on until turned off, and stays off', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.open();
    expect(settings.commanderDamage, isTrue);
    settings.setCommanderDamage(false);
    expect((await AppSettings.open()).commanderDamage, isFalse);
  });
}
