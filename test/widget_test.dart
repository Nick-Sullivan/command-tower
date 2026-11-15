import 'package:command_tower/game/game.dart';
import 'package:command_tower/main.dart';
import 'package:command_tower/widgets/player_panel.dart';
import 'package:command_tower/widgets/skull.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seats in the default 4-player layout, clockwise from the top end.
const _top = 0, _right = 1, _bottom = 2;

Finder _seat(int i) => find.byKey(ValueKey(('seat', i)));

Finder _textInSeat(int i, String text) =>
    find.descendant(of: _seat(i), matching: find.text(text));

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final game = Game();
  addTearDown(game.dispose);
  await tester.pumpWidget(MyApp(game: game));
}

/// Lets the running delta fade so no timers are left pending.
Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

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

  testWidgets('a new game applies the chosen players and life', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('6'));
    await tester.tap(find.text('20'));
    await tester.tap(find.byKey(const ValueKey(('layout', 1))));
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      expect(_textInSeat(i, '20'), findsOneWidget);
    }
  });
}
