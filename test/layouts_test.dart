import 'package:command_tower/game/layouts.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every player count from 2 to 6 has a layout', () {
    for (var n = minPlayers; n <= maxPlayers; n++) {
      expect(tableLayouts[n], isNotEmpty, reason: '$n players');
    }
  });

  group('others are ordered left to right from each seat', () {
    // Default 4-player layout: 0 top end, 1 right side, 2 bottom end, 3 left.
    final square = tableLayouts[4]![0];
    const phone = Size(392, 807);

    test('bottom end sees left, across, right', () {
      expect(othersLeftToRight(square, 2, phone), [3, 0, 1]);
    });

    test('top end, facing the other way, sees them mirrored', () {
      expect(othersLeftToRight(square, 0, phone), [1, 2, 3]);
    });

    test('left side has the top end on their left', () {
      expect(othersLeftToRight(square, 3, phone), [0, 1, 2]);
    });

    test('right side has the bottom end on their left', () {
      expect(othersLeftToRight(square, 1, phone), [2, 3, 0]);
    });

    test('with three per side, neighbours on the same side come first '
        'and last', () {
      // 0, 1, 2 down the right side; 3, 4, 5 up the left side.
      final sixSides = tableLayouts[6]![0];
      // The middle-right player has the lower neighbour on their left and
      // the upper one on their right, with the far side in between.
      final order = othersLeftToRight(sixSides, 1, phone);
      expect(order.first, 2);
      expect(order.last, 0);
      expect(order.sublist(1, 4).toSet(), {3, 4, 5});
    });
  });

  for (final MapEntry(key: count, value: layouts) in tableLayouts.entries) {
    for (var l = 0; l < layouts.length; l++) {
      final seats = layouts[l].seats;
      final name = '$count players, layout $l';

      test('$name has one seat per player', () {
        expect(seats, hasLength(count));
      });

      test('$name fills the screen without overlap', () {
        var area = 0.0;
        for (final seat in seats) {
          final r = seat.rect;
          expect(r.left >= 0 && r.top >= 0, isTrue, reason: name);
          expect(r.right <= 1 && r.bottom <= 1, isTrue, reason: name);
          area += r.width * r.height;
        }
        expect(area, closeTo(1, 1e-9), reason: name);
        for (var i = 0; i < seats.length; i++) {
          for (var j = i + 1; j < seats.length; j++) {
            final overlap = seats[i].rect.intersect(seats[j].rect);
            final overlapArea = overlap.width > 0 && overlap.height > 0
                ? overlap.width * overlap.height
                : 0.0;
            expect(overlapArea, closeTo(0, 1e-9), reason: '$name: $i and $j');
          }
        }
      });
    }
  }
}
