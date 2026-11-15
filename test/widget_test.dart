import 'package:command_tower/game/game.dart';
import 'package:command_tower/main.dart';
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
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
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
