/// Optional per-player counters, turned on for the whole table in settings.
///
/// Declared alphabetically: this is the order of the Tracking chips (after
/// Commander damage) and of the buttons on each panel.
enum Counter {
  commanderTax('Commander tax', step: 2),
  energy('Energy'),
  experience('Experience'),
  poison('Poison', lethal: 10);

  const Counter(this.label, {this.step = 1, this.lethal});

  final String label;

  /// How much one tap changes it: commander tax goes up 2 per recast.
  final int step;

  /// The value that knocks a player out, if any.
  final int? lethal;
}
