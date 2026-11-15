import 'package:flutter/material.dart';

import '../game/game.dart';
import '../game/layouts.dart';
import 'player_panel.dart';

/// The small button where the panels meet; opens the game settings.
class GameMenuButton extends StatelessWidget {
  const GameMenuButton({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.settings, color: Colors.white70),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          // Size to the content rather than the default cap of 9/16 height.
          isScrollControlled: true,
          builder: (_) => GameMenuSheet(game: game),
        ),
      ),
    );
  }
}

/// Settings for the next game. Nothing changes until "New game", so a game in
/// progress can't be reset by accident.
class GameMenuSheet extends StatefulWidget {
  const GameMenuSheet({super.key, required this.game});

  final Game game;

  @override
  State<GameMenuSheet> createState() => _GameMenuSheetState();
}

class _GameMenuSheetState extends State<GameMenuSheet> {
  late int _players = widget.game.playerCount;
  late int _layout = widget.game.layoutIndex;
  late int _life = widget.game.startingLife;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final layouts = tableLayouts[_players]!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Players', style: titleStyle),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var n = minPlayers; n <= maxPlayers; n++)
                  ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {_players},
              onSelectionChanged: (s) => setState(() {
                _players = s.first;
                _layout = 0;
              }),
            ),
            const SizedBox(height: 24),
            Text('Layout', style: titleStyle),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < layouts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: LayoutThumbnail(
                      key: ValueKey(('layout', i)),
                      layout: layouts[i],
                      selected: i == _layout,
                      onTap: () => setState(() => _layout = i),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Starting life', style: titleStyle),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 20, label: Text('20')),
                ButtonSegment(value: 30, label: Text('30')),
                ButtonSegment(value: 40, label: Text('40')),
              ],
              selected: {_life},
              onSelectionChanged: (s) => setState(() => _life = s.first),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () {
                widget.game.newGame(
                  playerCount: _players,
                  layoutIndex: _layout,
                  startingLife: _life,
                );
                Navigator.pop(context);
              },
              child: const Text('New game'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A miniature of a layout: each seat in its player's colour, with a number
/// turned to face that seat.
class LayoutThumbnail extends StatelessWidget {
  const LayoutThumbnail({
    super.key,
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  final TableLayout layout;
  final bool selected;
  final VoidCallback onTap;

  static const _size = Size(56, 112);

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox.fromSize(
          size: _size,
          child: Stack(
            children: [
              for (var i = 0; i < layout.seats.length; i++)
                Positioned.fromRect(
                  rect: Rect.fromLTRB(
                    layout.seats[i].rect.left * _size.width,
                    layout.seats[i].rect.top * _size.height,
                    layout.seats[i].rect.right * _size.width,
                    layout.seats[i].rect.bottom * _size.height,
                  ).deflate(1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: playerColors[i],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: RotatedBox(
                      quarterTurns: layout.seats[i].quarterTurns,
                      child: const Center(
                        child: Text(
                          '40',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
