import 'package:flutter/painting.dart';

/// Which edge of the phone a player sits at, as clockwise quarter turns that
/// make their panel read upright for them. The phone lies flat, portrait.
const _bottom = 0;
const _left = 1;
const _top = 2;
const _right = 3;

/// One player's place at the table: where their panel sits, as fractions of
/// the screen, and how many clockwise quarter turns make it face them.
class Seat {
  const Seat(this.rect, this.quarterTurns);

  final Rect rect;
  final int quarterTurns;
}

/// A seating arrangement. Seats run clockwise around the table, viewed from
/// above.
class TableLayout {
  const TableLayout(this.seats);

  final List<Seat> seats;
}

const minPlayers = 2;
const maxPlayers = 6;

/// Preset layouts per player count; the first is the default.
const Map<int, List<TableLayout>> tableLayouts = {
  2: [
    // One at each end.
    TableLayout([
      Seat(Rect.fromLTRB(0, 0, 1, .5), _top),
      Seat(Rect.fromLTRB(0, .5, 1, 1), _bottom),
    ]),
    // One on each side.
    TableLayout([
      Seat(Rect.fromLTRB(.5, 0, 1, 1), _right),
      Seat(Rect.fromLTRB(0, 0, .5, 1), _left),
    ]),
  ],
  3: [
    TableLayout([
      Seat(Rect.fromLTRB(0, 0, 1, .4), _top),
      Seat(Rect.fromLTRB(.5, .4, 1, 1), _right),
      Seat(Rect.fromLTRB(0, .4, .5, 1), _left),
    ]),
    TableLayout([
      Seat(Rect.fromLTRB(.5, 0, 1, .6), _right),
      Seat(Rect.fromLTRB(0, .6, 1, 1), _bottom),
      Seat(Rect.fromLTRB(0, 0, .5, .6), _left),
    ]),
  ],
  4: [
    // One on each edge, as around a square table.
    TableLayout([
      Seat(Rect.fromLTRB(0, 0, 1, .3), _top),
      Seat(Rect.fromLTRB(.5, .3, 1, .7), _right),
      Seat(Rect.fromLTRB(0, .7, 1, 1), _bottom),
      Seat(Rect.fromLTRB(0, .3, .5, .7), _left),
    ]),
    // Two on each side.
    TableLayout([
      Seat(Rect.fromLTRB(.5, 0, 1, .5), _right),
      Seat(Rect.fromLTRB(.5, .5, 1, 1), _right),
      Seat(Rect.fromLTRB(0, .5, .5, 1), _left),
      Seat(Rect.fromLTRB(0, 0, .5, .5), _left),
    ]),
  ],
  5: [
    TableLayout([
      Seat(Rect.fromLTRB(.5, 0, 1, .35), _right),
      Seat(Rect.fromLTRB(.5, .35, 1, .7), _right),
      Seat(Rect.fromLTRB(0, .7, 1, 1), _bottom),
      Seat(Rect.fromLTRB(0, .35, .5, .7), _left),
      Seat(Rect.fromLTRB(0, 0, .5, .35), _left),
    ]),
    TableLayout([
      Seat(Rect.fromLTRB(0, 0, 1, .3), _top),
      Seat(Rect.fromLTRB(.5, .3, 1, .65), _right),
      Seat(Rect.fromLTRB(.5, .65, 1, 1), _right),
      Seat(Rect.fromLTRB(0, .65, .5, 1), _left),
      Seat(Rect.fromLTRB(0, .3, .5, .65), _left),
    ]),
  ],
  6: [
    // Three on each side.
    TableLayout([
      Seat(Rect.fromLTRB(.5, 0, 1, 1 / 3), _right),
      Seat(Rect.fromLTRB(.5, 1 / 3, 1, 2 / 3), _right),
      Seat(Rect.fromLTRB(.5, 2 / 3, 1, 1), _right),
      Seat(Rect.fromLTRB(0, 2 / 3, .5, 1), _left),
      Seat(Rect.fromLTRB(0, 1 / 3, .5, 2 / 3), _left),
      Seat(Rect.fromLTRB(0, 0, .5, 1 / 3), _left),
    ]),
    // Two on each side and one at each end.
    TableLayout([
      Seat(Rect.fromLTRB(0, 0, 1, .25), _top),
      Seat(Rect.fromLTRB(.5, .25, 1, .5), _right),
      Seat(Rect.fromLTRB(.5, .5, 1, .75), _right),
      Seat(Rect.fromLTRB(0, .75, 1, 1), _bottom),
      Seat(Rect.fromLTRB(0, .5, .5, .75), _left),
      Seat(Rect.fromLTRB(0, .25, .5, .5), _left),
    ]),
  ],
};
