import 'dart:math';

import 'package:command_tower/game/dice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every die rolls 1 to its sides, and can roll each', () {
    final random = Random(1);
    for (final die in Die.values) {
      final seen = {for (var i = 0; i < die.sides * 40; i++) die.roll(random)};
      expect(seen, {for (var n = 1; n <= die.sides; n++) n}, reason: die.label);
    }
  });

  test('the coin reads as heads or tails', () {
    expect(Die.coin.show(1), 'Heads');
    expect(Die.coin.show(2), 'Tails');
    expect(Die.d20.show(17), '17');
  });
}
