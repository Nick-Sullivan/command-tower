import 'package:command_tower/game/dice.dart';
import 'package:command_tower/game/game.dart';
import 'package:command_tower/main.dart';
import 'package:command_tower/settings/app_settings.dart';
import 'package:command_tower/sound/sounds.dart';
import 'package:command_tower/widgets/player_panel.dart';
import 'package:command_tower/widgets/skull.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seats in the default 4-player layout, clockwise from the top end.
const _top = 0, _right = 1, _bottom = 2;

Finder _seat(int i) => find.byKey(ValueKey(('seat', i)));

Finder _textInSeat(int i, String text) =>
    find.descendant(of: _seat(i), matching: find.text(text));

/// Records what would have played, instead of playing it.
class _FakeSounds implements SoundPlayer {
  final played = <Sound>[];

  @override
  void play(Sound sound) => played.add(sound);
}

late _FakeSounds _sounds;
late Game _game;

Future<AppSettings> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final game = _game = Game();
  addTearDown(game.dispose);
  SharedPreferences.setMockInitialValues({});
  final settings = await AppSettings.open();
  addTearDown(settings.dispose);
  _sounds = _FakeSounds();
  await tester.pumpWidget(
    MyApp(game: game, settings: settings, sounds: _sounds),
  );
  return settings;
}

/// Lets the running delta fade and any counter view time out, so no timers
/// are left pending.
Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 6));

void main() {
  testWidgets('tapping the left half lowers life, the right raises it', (
    tester,
  ) async {
    await _pumpApp(tester);
    final rect = tester.getRect(_seat(_bottom));

    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
    await tester.pump();
    expect(_textInSeat(_bottom, '39'), findsOneWidget);
    expect(_textInSeat(_bottom, '−1'), findsOneWidget);

    await tester.tapAt(Offset(rect.right - rect.width / 4, rect.center.dy));
    await tester.tapAt(Offset(rect.right - rect.width / 4, rect.center.dy));
    await tester.pump();
    expect(_textInSeat(_bottom, '41'), findsOneWidget);
    expect(_textInSeat(_bottom, '+1'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('left and right are from the seat, on a rotated panel', (
    tester,
  ) async {
    await _pumpApp(tester);
    // The right-side player faces left across the table, so their left hand
    // is toward the bottom of the screen.
    final rect = tester.getRect(_seat(_right));

    await tester.tapAt(Offset(rect.center.dx, rect.bottom - rect.height / 4));
    await tester.pump();
    expect(_textInSeat(_right, '39'), findsOneWidget);

    // The top-end player is upside down, so their left is the screen's right.
    final top = tester.getRect(_seat(_top));
    await tester.tapAt(Offset(top.right - top.width / 4, top.center.dy));
    await tester.pump();
    expect(_textInSeat(_top, '39'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('no haptic click once Vibration is turned off', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      },
    );
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Vibration'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(_seat(_bottom));
    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
    await tester.pump();
    expect(_textInSeat(_bottom, '39'), findsOneWidget);
    expect(haptics, isEmpty);
    await _settle(tester);
  });

  testWidgets('every change gives a light haptic tick', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    await _pumpApp(tester);
    final rect = tester.getRect(_seat(_bottom));

    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
    await tester.tapAt(Offset(rect.right - rect.width / 4, rect.center.dy));
    // Switching to commander damage and back isn't a change, so no click.
    final swords = find.descendant(
      of: _seat(_bottom),
      matching: find.byKey(const ValueKey('commander-damage')),
    );
    await tester.tap(swords);
    await tester.pump();
    await tester.tap(swords);
    await tester.pump();
    expect(haptics, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.lightImpact',
    ]);
    await _settle(tester);
  });

  testWidgets('the pressed half lights up until released', (tester) async {
    await _pumpApp(tester);
    final rect = tester.getRect(_seat(_bottom));
    Color? halfColor(int sign) {
      final half = find.descendant(
        of: _seat(_bottom),
        matching: find.byKey(ValueKey(('half', sign))),
      );
      final box = tester.widget<AnimatedContainer>(half).decoration;
      return (box as BoxDecoration?)?.color;
    }

    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width / 4, rect.center.dy),
    );
    await tester.pump();
    expect(halfColor(-1)!.a, greaterThan(0));
    expect(halfColor(1)!.a, 0);

    await gesture.up();
    await tester.pump();
    expect(halfColor(-1)!.a, 0);
    await _settle(tester);
  });

  testWidgets('holding repeats in steps of 10', (tester) async {
    await _pumpApp(tester);
    final rect = tester.getRect(_seat(_bottom));

    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width / 4, rect.center.dy),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(_textInSeat(_bottom, '30'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(_textInSeat(_bottom, '20'), findsOneWidget);
    expect(_textInSeat(_bottom, '−20'), findsOneWidget);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(_textInSeat(_bottom, '20'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('at 0 life the panel fogs over but keeps working', (
    tester,
  ) async {
    await _pumpApp(tester);
    final rect = tester.getRect(_seat(_bottom));
    final minus = Offset(rect.left + rect.width / 4, rect.center.dy);
    final plus = Offset(rect.right - rect.width / 4, rect.center.dy);
    double fog() => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: _seat(_bottom),
            matching: find.byKey(const ValueKey('fog')),
          ),
        )
        .opacity;

    // Hold to drop from 40 to 0.
    final gesture = await tester.startGesture(minus);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    await gesture.up();
    expect(_textInSeat(_bottom, '0'), findsOneWidget);
    expect(fog(), 1);
    double skull() => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.descendant(
                  of: _seat(_bottom),
                  matching: find.byKey(const ValueKey('knocked-out-skull')),
                ),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;
    // The running change shows first; the skull once it fades.
    expect(skull(), 0);
    await tester.pump(const Duration(seconds: 3));
    expect(skull(), 1);

    // Still going below 0, and back up again.
    await tester.tapAt(minus);
    await tester.pump();
    expect(_textInSeat(_bottom, '−1'), findsWidgets);
    await tester.tapAt(plus);
    await tester.tapAt(plus);
    await tester.pump();
    expect(_textInSeat(_bottom, '1'), findsOneWidget);
    expect(fog(), 0);
    expect(skull(), 0);
    await _settle(tester);
  });

  group('commander damage', () {
    Finder swords(int seat) => find.descendant(
      of: _seat(seat),
      matching: find.byKey(const ValueKey('commander-damage')),
    );
    Finder damageFrom(int seat, int from) => find.descendant(
      of: _seat(seat),
      matching: find.byKey(ValueKey(('damage-from', from))),
    );

    testWidgets('the swords open damage mode with one area per opponent, '
        'and close it again', (tester) async {
      await _pumpApp(tester);
      expect(damageFrom(_bottom, _top), findsNothing);

      await tester.tap(swords(_bottom));
      await tester.pump();
      for (final from in [0, 1, 3]) {
        expect(damageFrom(_bottom, from), findsOneWidget);
      }
      expect(damageFrom(_bottom, _bottom), findsNothing);
      // Other panels are unaffected.
      expect(damageFrom(_top, _bottom), findsNothing);

      await tester.tap(swords(_bottom));
      await tester.pump();
      expect(damageFrom(_bottom, _top), findsNothing);
      expect(_textInSeat(_bottom, '40'), findsOneWidget);
    });

    testWidgets('lethal damage shows a skull and keeps the colour', (
      tester,
    ) async {
      await _pumpApp(tester);
      await tester.tap(swords(_bottom));
      await tester.pump();
      final area = tester.getRect(damageFrom(_bottom, _top));
      final plus = Offset(area.right - area.width / 4, area.center.dy);
      Finder skull() => find.descendant(
        of: damageFrom(_bottom, _top),
        matching: find.byType(Skull),
      );

      for (var i = 0; i < 20; i++) {
        await tester.tapAt(plus);
      }
      await tester.pump();
      expect(skull(), findsNothing);

      await tester.tapAt(plus);
      await tester.pump();
      expect(skull(), findsOneWidget);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: damageFrom(_bottom, _top),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, playerColors[_top]);
      await _settle(tester);
    });

    testWidgets('goes back to life 5 seconds after the last tap', (
      tester,
    ) async {
      await _pumpApp(tester);
      await tester.tap(swords(_bottom));
      await tester.pump();
      final area = tester.getRect(damageFrom(_bottom, _top));

      // Each tap restarts the countdown.
      await tester.pump(const Duration(seconds: 4));
      await tester.tapAt(Offset(area.right - area.width / 4, area.center.dy));
      await tester.pump(const Duration(seconds: 4));
      expect(damageFrom(_bottom, _top), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(damageFrom(_bottom, _top), findsNothing);
      expect(_textInSeat(_bottom, '39'), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('opponent areas sit where those players sit', (tester) async {
      await _pumpApp(tester);
      await tester.tap(swords(_bottom));
      await tester.pump();
      // From the bottom end: left side (3), top end (0), right side (1).
      final xs = [
        for (final from in [3, 0, 1])
          tester.getCenter(damageFrom(_bottom, from)).dx,
      ];
      expect(xs[0], lessThan(xs[1]));
      expect(xs[1], lessThan(xs[2]));
    });

    testWidgets('adding damage takes it off life, and minus gives it back', (
      tester,
    ) async {
      await _pumpApp(tester);
      await tester.tap(swords(_bottom));
      await tester.pump();
      final area = tester.getRect(damageFrom(_bottom, _top));
      final plus = Offset(area.right - area.width / 4, area.center.dy);
      final minus = Offset(area.left + area.width / 4, area.center.dy);

      for (var i = 0; i < 3; i++) {
        await tester.tapAt(plus);
      }
      await tester.pump();
      expect(
        find.descendant(
          of: damageFrom(_bottom, _top),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(_textInSeat(_bottom, '37'), findsOneWidget);

      await tester.tapAt(minus);
      await tester.pump();
      expect(_textInSeat(_bottom, '38'), findsOneWidget);

      // Below zero does nothing.
      for (var i = 0; i < 4; i++) {
        await tester.tapAt(minus);
      }
      await tester.pump();
      expect(_textInSeat(_bottom, '40'), findsOneWidget);

      // Damage is still there after closing and reopening.
      await tester.tapAt(plus);
      await tester.tap(swords(_bottom));
      await tester.pump();
      expect(_textInSeat(_bottom, '39'), findsOneWidget);
      await tester.tap(swords(_bottom));
      await tester.pump();
      expect(
        find.descendant(
          of: damageFrom(_bottom, _top),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await _settle(tester);
    });
  });

  group('counters', () {
    Finder counterButton(int seat, Counter c) => find.descendant(
      of: _seat(seat),
      matching: find.byKey(ValueKey(('counter', c.name))),
    );
    Finder counterArea(int seat, Counter c) => find.descendant(
      of: _seat(seat),
      matching: find.byKey(ValueKey(('counter-area', c.name))),
    );

    testWidgets('turned on from More settings, they appear on every panel', (
      tester,
    ) async {
      await _pumpApp(tester);
      expect(counterButton(_bottom, Counter.poison), findsNothing);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tracking'));
      await tester.pumpAndSettle();
      // Counters apply as they're chosen, so there's nothing to Start.
      expect(find.text('Start'), findsNothing);
      await tester.tap(find.text('Poison'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      for (var seat = 0; seat < 4; seat++) {
        expect(counterButton(seat, Counter.poison), findsOneWidget);
      }
      expect(counterButton(_bottom, Counter.energy), findsNothing);
    });

    testWidgets('a counter button shows it big, with − and + halves', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      settings.setCounter(Counter.poison, true);
      settings.setCounter(Counter.commanderTax, true);
      await tester.pump();

      await tester.tap(counterButton(_bottom, Counter.poison));
      await tester.pump();
      final area = tester.getRect(counterArea(_bottom, Counter.poison));
      final plus = Offset(area.right - area.width / 4, area.center.dy);
      await tester.tapAt(plus);
      await tester.tapAt(plus);
      await tester.pump();
      expect(
        find.descendant(
          of: counterArea(_bottom, Counter.poison),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      // Life is untouched, and still shown beside the buttons.
      expect(_textInSeat(_bottom, '40'), findsOneWidget);

      // Back to life, with the value on the button.
      await tester.tap(counterButton(_bottom, Counter.poison));
      await tester.pump();
      expect(counterArea(_bottom, Counter.poison), findsNothing);
      expect(
        find.descendant(
          of: counterButton(_bottom, Counter.poison),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      // Commander tax goes up 2 per tap.
      await tester.tap(counterButton(_bottom, Counter.commanderTax));
      await tester.pump();
      final tax = tester.getRect(counterArea(_bottom, Counter.commanderTax));
      await tester.tapAt(Offset(tax.right - tax.width / 4, tax.center.dy));
      await tester.pump();
      expect(
        find.descendant(
          of: counterArea(_bottom, Counter.commanderTax),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      // The swords switch straight from a counter to commander damage.
      await tester.tap(
        find.descendant(
          of: _seat(_bottom),
          matching: find.byKey(const ValueKey('commander-damage')),
        ),
      );
      await tester.pump();
      expect(counterArea(_bottom, Counter.commanderTax), findsNothing);
      expect(
        find.descendant(
          of: _seat(_bottom),
          matching: find.byKey(const ValueKey(('damage-from', _top))),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a counter goes back to life 5 seconds after the last tap', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      settings.setCounter(Counter.poison, true);
      await tester.pump();
      await tester.tap(counterButton(_bottom, Counter.poison));
      await tester.pump();
      final area = tester.getRect(counterArea(_bottom, Counter.poison));

      // Each tap restarts the countdown.
      await tester.pump(const Duration(seconds: 4));
      await tester.tapAt(Offset(area.right - area.width / 4, area.center.dy));
      await tester.pump(const Duration(seconds: 4));
      expect(counterArea(_bottom, Counter.poison), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(counterArea(_bottom, Counter.poison), findsNothing);
      expect(_textInSeat(_bottom, '40'), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('the buttons stay centred in every view', (tester) async {
      final settings = await _pumpApp(tester);
      final panel = tester.getRect(_seat(_bottom));
      final swords = find.descendant(
        of: _seat(_bottom),
        matching: find.byKey(const ValueKey('commander-damage')),
      );
      expect(tester.getCenter(swords).dx, closeTo(panel.center.dx, 1));

      // With two counters, the swords + tax + poison group is centred.
      settings.setCounter(Counter.poison, true);
      settings.setCounter(Counter.commanderTax, true);
      await tester.pump();
      double groupCentre() =>
          (tester.getRect(swords).left +
              tester.getRect(counterButton(_bottom, Counter.poison)).right) /
          2;
      expect(groupCentre(), closeTo(panel.center.dx, 1));

      // Still centred with the life total showing beside them.
      await tester.tap(counterButton(_bottom, Counter.poison));
      await tester.pump();
      expect(groupCentre(), closeTo(panel.center.dx, 1));
    });

    testWidgets('commander damage can be turned off and on from Tracking', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      final swords = find.descendant(
        of: _seat(_bottom),
        matching: find.byKey(const ValueKey('commander-damage')),
      );
      expect(settings.commanderDamage, isTrue);
      await tester.tap(swords);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tracking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commander damage'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // The swords are gone, and the panel that was showing damage is back
      // on life.
      expect(swords, findsNothing);
      expect(_textInSeat(_bottom, '40'), findsOneWidget);

      settings.setCommanderDamage(true);
      await tester.pump();
      expect(swords, findsOneWidget);
    });

    testWidgets('turning a counter off while it is shown goes back to life', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      settings.setCounter(Counter.energy, true);
      await tester.pump();
      await tester.tap(counterButton(_bottom, Counter.energy));
      await tester.pump();
      expect(counterArea(_bottom, Counter.energy), findsOneWidget);

      settings.setCounter(Counter.energy, false);
      await tester.pump();
      expect(counterArea(_bottom, Counter.energy), findsNothing);
      expect(_textInSeat(_bottom, '40'), findsOneWidget);
    });
  });

  group('sound', () {
    testWidgets('silent until turned on', (tester) async {
      await _pumpApp(tester);
      final rect = tester.getRect(_seat(_bottom));
      await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
      expect(_sounds.played, isEmpty);
      await _settle(tester);
    });

    testWidgets('each half plays its sound, on life, damage and counters', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      settings.setSoundOn(true);
      settings.setCounter(Counter.poison, true);
      await tester.pump();
      final rect = tester.getRect(_seat(_bottom));

      await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
      await tester.tapAt(Offset(rect.right - rect.width / 4, rect.center.dy));
      expect(_sounds.played, [
        settings.sound(SoundRole.minus),
        settings.sound(SoundRole.plus),
      ]);

      // Adding commander damage takes life away, so it plays the − sound.
      await tester.tap(
        find.descendant(
          of: _seat(_bottom),
          matching: find.byKey(const ValueKey('commander-damage')),
        ),
      );
      await tester.pump();
      final area = tester.getRect(
        find.descendant(
          of: _seat(_bottom),
          matching: find.byKey(const ValueKey(('damage-from', _top))),
        ),
      );
      await tester.tapAt(Offset(area.right - area.width / 4, area.center.dy));
      expect(_sounds.played.last, settings.sound(SoundRole.minus));
      await _settle(tester);
    });

    testWidgets('counters are silent: sound is for health only', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      settings.setSoundOn(true);
      settings.setCounter(Counter.poison, true);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: _seat(_bottom),
          matching: find.byKey(const ValueKey(('counter', 'poison'))),
        ),
      );
      await tester.pump();
      final area = tester.getRect(
        find.descendant(
          of: _seat(_bottom),
          matching: find.byKey(const ValueKey(('counter-area', 'poison'))),
        ),
      );
      await tester.tapAt(Offset(area.right - area.width / 4, area.center.dy));
      await tester.tapAt(Offset(area.left + area.width / 4, area.center.dy));
      expect(_sounds.played, isEmpty);
      await _settle(tester);
    });

    testWidgets('being knocked out plays its sound, once', (tester) async {
      final settings = await _pumpApp(tester);
      settings.setSoundOn(true);
      await tester.pump();
      final rect = tester.getRect(_seat(_bottom));
      final minus = Offset(rect.left + rect.width / 4, rect.center.dy);

      // Hold to drop from 40 to 0, then one more tap below 0.
      final gesture = await tester.startGesture(minus);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 600));
      }
      await gesture.up();
      await tester.tapAt(minus);
      await tester.pump();
      // Once, or not at all while there are no knocked-out sounds (None is
      // never played).
      final knockOut = settings.sound(SoundRole.knockedOut);
      expect(
        _sounds.played.where((s) => s == knockOut),
        hasLength(knockOut == Sound.none ? 0 : 1),
      );
      expect(_sounds.played, isNot(contains(Sound.none)));
      await _settle(tester);
    });

    testWidgets('choosing a sound in the Sound tab plays and keeps it', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device'));
      await tester.pumpAndSettle();
      // The choices are there but greyed out until sound is on.
      final plusRow = find.byKey(const ValueKey(('sound', 'plus')));
      DropdownMenu<Sound> plusMenu() => tester.widget<DropdownMenu<Sound>>(
        find.descendant(
          of: plusRow,
          matching: find.byType(DropdownMenu<Sound>),
        ),
      );
      expect(plusMenu().enabled, isFalse);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Sound'));
      await tester.pumpAndSettle();
      expect(plusMenu().enabled, isTrue);

      // Each row only offers its own kind of sound.
      final offered = [for (final e in plusMenu().dropdownMenuEntries) e.value];
      expect(offered, contains(Sound.phaserUp));
      expect(offered, isNot(contains(Sound.hurt)));

      await tester.tap(
        find.descendant(
          of: plusRow,
          matching: find.byType(DropdownMenu<Sound>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phaser up').last);
      await tester.pumpAndSettle();
      expect(settings.sound(SoundRole.plus), Sound.phaserUp);
      expect(_sounds.played, [Sound.phaserUp]);
    });
  });

  group('dice', () {
    final diceButton = find.byKey(const ValueKey('dice-button'));

    testWidgets('turned on in Tracking, they add a button beside the ⚙', (
      tester,
    ) async {
      await _pumpApp(tester);
      expect(diceButton, findsNothing);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tracking'));
      await tester.pumpAndSettle();
      // Which dice to offer only shows once dice are on.
      expect(find.byKey(const ValueKey('dice-shown')), findsNothing);
      await tester.tap(find.text('Dice'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dice-shown')), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(diceButton, findsOneWidget);
      // Side by side, centred together.
      final gear = tester.getRect(
        find.ancestor(
          of: find.byIcon(Icons.settings),
          matching: find.byType(IconButton),
        ),
      );
      final dice = tester.getRect(diceButton);
      final screen = tester.getRect(find.byType(Scaffold));
      expect((gear.left + dice.right) / 2, closeTo(screen.center.dx, 1));
    });

    testWidgets('the button pops out the chosen dice; tap one to roll it', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      settings.setDice(true);
      settings.setDieShown(Die.d8, true);
      await tester.pump();
      Finder die(Die d) => find.byKey(ValueKey(('die', d.name)));
      Finder dieResult(Die d) => find.byKey(ValueKey(('die-result', d.name)));
      String resultOf(Die d) => tester.widget<Text>(dieResult(d)).data!;

      await tester.tap(diceButton);
      await tester.pump();
      // Just the dice chosen in Tracking, each showing its name.
      for (final d in Die.values) {
        expect(
          die(d),
          settings.diceShown.contains(d) ? findsOneWidget : findsNothing,
        );
      }
      expect(dieResult(Die.d20), findsNothing);

      // Tapping a die rolls it in place.
      await tester.tap(die(Die.d20));
      await tester.pump(const Duration(milliseconds: 700));
      expect(int.parse(resultOf(Die.d20)), inInclusiveRange(1, 20));
      await tester.tap(die(Die.coin));
      await tester.pump(const Duration(milliseconds: 700));
      expect(['Heads', 'Tails'], contains(resultOf(Die.coin)));
      // Each die keeps its own result.
      expect(dieResult(Die.d20), findsOneWidget);

      // Tapping off the dice tucks them away.
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      expect(die(Die.d20), findsNothing);
      expect(_game.life, [40, 40, 40, 40]);
    });

    testWidgets('the last die chosen stays on, and isn\'t greyed out', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      settings.setDice(true);
      settings.setDieShown(Die.coin, false);
      settings.setDieShown(Die.d6, false);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tracking'));
      await tester.pumpAndSettle();
      final d20 = find.widgetWithText(FilterChip, 'd20');
      expect(tester.widget<FilterChip>(d20).onSelected, isNotNull);
      await tester.tap(d20);
      await tester.pump();
      expect(settings.diceShown, [Die.d20]);
      expect(tester.widget<FilterChip>(d20).selected, isTrue);
    });
  });

  group('random starting player', () {
    final highlight = find.byKey(const ValueKey('starting-player-highlight'));

    Future<void> startNewGame(
      WidgetTester tester, {
      required bool random,
    }) async {
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      if (random) {
        await tester.tap(find.text('Random starting player'));
        await tester.pump();
      }
      await tester.tap(find.text('Start'));
      await tester.pump();
    }

    testWidgets('off by default: Start picks nobody', (tester) async {
      await _pumpApp(tester);
      await startNewGame(tester, random: false);
      await tester.pumpAndSettle();
      expect(_game.startingPlayer, isNull);
      expect(highlight, findsNothing);
    });

    testWidgets('spins, lands on the chosen player, and clears on a touch', (
      tester,
    ) async {
      final settings = await _pumpApp(tester);
      await startNewGame(tester, random: true);
      expect(settings.randomStartingPlayer, isTrue);
      final chosen = _game.startingPlayer!;
      expect(chosen, inInclusiveRange(0, 3));
      expect(highlight, findsOneWidget);

      // After the spin, the highlight sits on the chosen player's panel.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(tester.getRect(highlight), tester.getRect(_seat(chosen)));

      // The first touch clears it, and changes nothing else.
      final rect = tester.getRect(_seat(_bottom));
      await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
      await tester.pump();
      expect(_game.startingPlayer, isNull);
      expect(highlight, findsNothing);
      await _settle(tester);
    });

    testWidgets('picks across the whole table', (tester) async {
      await _pumpApp(tester);
      final picked = <int>{};
      for (var i = 0; i < 40 && picked.length < 4; i++) {
        await startNewGame(tester, random: i == 0);
        picked.add(_game.startingPlayer!);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
      expect(picked, {0, 1, 2, 3});
    });
  });

  testWidgets('a new game applies the chosen players and life', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('6'));
    await tester.tap(find.text('20'));
    await tester.tap(find.byKey(const ValueKey(('layout', 1))));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      expect(_textInSeat(i, '20'), findsOneWidget);
    }
  });

  group('Start asks first if it would lose a game in progress', () {
    Future<void> changeLifeThenStart(WidgetTester tester) async {
      final rect = tester.getRect(_seat(_bottom));
      await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
    }

    testWidgets('cancelling keeps the game', (tester) async {
      await _pumpApp(tester);
      await changeLifeThenStart(tester);
      expect(find.text('Start a new game?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(_game.life[_bottom], 39);
      // Back in the menu, nothing started.
      expect(find.text('Random starting player'), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('confirming starts the new game', (tester) async {
      await _pumpApp(tester);
      await changeLifeThenStart(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-start')));
      await tester.pumpAndSettle();
      expect(_game.life[_bottom], 40);
      expect(find.text('Start a new game?'), findsNothing);
      expect(find.text('Random starting player'), findsNothing);
    });

    testWidgets('no question when nothing has happened yet', (tester) async {
      await _pumpApp(tester);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('Start a new game?'), findsNothing);
      expect(find.text('Random starting player'), findsNothing);
    });
  });

  testWidgets('cancel leaves the game as it was', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsNothing);
    expect(_seat(4), findsNothing);
    expect(_textInSeat(_bottom, '40'), findsOneWidget);
  });
}
