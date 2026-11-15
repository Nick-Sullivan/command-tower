import 'package:command_tower/game/layouts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every player count from 2 to 6 has a layout', () {
    for (var n = minPlayers; n <= maxPlayers; n++) {
      expect(tableLayouts[n], isNotEmpty, reason: '$n players');
    }
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
