import 'dart:io';

import 'package:command_tower/game/counters.dart';
import 'package:command_tower/game/dice.dart';
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
    expect(settings.sound(SoundRole.minus), Sound.hurt.choice);
    expect(settings.sound(SoundRole.plus), Sound.doubleCoin.choice);
    expect(settings.sound(SoundRole.knockedOut), Sound.fall.choice);

    settings.setSoundOn(true);
    settings.setSound(SoundRole.minus, Sound.none.choice);
    settings.setSound(SoundRole.plus, Sound.phaserUp.choice);
    final relaunched = await AppSettings.open();
    expect(relaunched.soundOn, isTrue);
    expect(relaunched.sound(SoundRole.minus), Sound.none.choice);
    expect(relaunched.sound(SoundRole.plus), Sound.phaserUp.choice);
  });

  test('imported sounds are offered for every role and remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.open();
    settings.addImportedSound('life points.mp3');
    const imported = SoundChoice.file('life points.mp3');
    for (final role in SoundRole.values) {
      expect(settings.soundChoices(role).last, imported, reason: role.name);
    }
    settings.setSound(SoundRole.minus, imported);
    final relaunched = await AppSettings.open();
    expect(relaunched.sound(SoundRole.minus), imported);
    expect(imported.label, 'life points');
  });

  test('a chosen sound file that is no longer imported falls back', () async {
    SharedPreferences.setMockInitialValues({'sound.minus': 'file:gone.mp3'});
    final settings = await AppSettings.open();
    expect(settings.sound(SoundRole.minus), Sound.hurt.choice);
  });

  test('a saved sound that is no longer offered falls back to default', () {
    // e.g. 'thud' from the first version, or a sound from another role.
    SharedPreferences.setMockInitialValues({
      'sound.minus': 'thud',
      'sound.plus': 'youLose',
    });
    return AppSettings.open().then((settings) {
      expect(settings.sound(SoundRole.minus), Sound.hurt.choice);
      expect(settings.sound(SoundRole.plus), Sound.doubleCoin.choice);
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

  test(
    'dice are off, offering coin, d6 and d20 until chosen otherwise',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.open();
      expect(settings.dice, isFalse);
      expect(settings.diceShown, [Die.coin, Die.d6, Die.d20]);

      settings.setDice(true);
      settings.setDieShown(Die.d4, true);
      settings.setDieShown(Die.coin, false);
      final relaunched = await AppSettings.open();
      expect(relaunched.dice, isTrue);
      expect(relaunched.diceShown, [Die.d4, Die.d6, Die.d20]);
    },
  );

  test('the last die shown can never be hidden', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.open();
    settings.setDieShown(Die.coin, false);
    settings.setDieShown(Die.d6, false);
    settings.setDieShown(Die.d20, false);
    expect(settings.diceShown, [Die.d20]);
  });

  test('vibration and keep screen on are on until turned off', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.open();
    expect(settings.vibration, isTrue);
    expect(settings.keepScreenOn, isTrue);
    settings.setVibration(false);
    settings.setKeepScreenOn(false);
    final relaunched = await AppSettings.open();
    expect(relaunched.vibration, isFalse);
    expect(relaunched.keepScreenOn, isFalse);
  });

  test('random starting player is off until turned on, and stays on', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.open();
    expect(settings.randomStartingPlayer, isFalse);
    settings.setRandomStartingPlayer(true);
    expect((await AppSettings.open()).randomStartingPlayer, isTrue);
  });

  test('commander damage is on until turned off, and stays off', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.open();
    expect(settings.commanderDamage, isTrue);
    settings.setCommanderDamage(false);
    expect((await AppSettings.open()).commanderDamage, isFalse);
  });
}
