import 'dart:math';

/// The dice the roller can offer; which appear is chosen in Tracking.
enum Die {
  coin('Coin', 2),
  d4('d4', 4),
  d6('d6', 6),
  d8('d8', 8),
  d10('d10', 10),
  d12('d12', 12),
  d20('d20', 20),
  d100('d100', 100);

  const Die(this.label, this.sides);

  final String label;
  final int sides;

  /// Rolls it: 1 to [sides].
  int roll(Random random) => random.nextInt(sides) + 1;

  /// How a result reads: Heads or Tails for the coin, the number otherwise.
  String show(int result) =>
      this == coin ? (result == 1 ? 'Heads' : 'Tails') : '$result';
}
