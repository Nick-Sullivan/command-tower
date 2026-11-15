import 'package:command_tower/game/counters.dart';
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

  test('commander damage is on until turned off, and stays off', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.open();
    expect(settings.commanderDamage, isTrue);
    settings.setCommanderDamage(false);
    expect((await AppSettings.open()).commanderDamage, isFalse);
  });
}
