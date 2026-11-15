import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game.dart';
import '../game/layouts.dart';
import '../settings/app_settings.dart';
import '../settings/sound_settings.dart';
import '../settings/tracking_settings.dart';
import 'player_panel.dart';

/// The small button where the panels meet; opens the new game dialog.
class GameMenuButton extends StatelessWidget {
  const GameMenuButton({super.key, required this.game, required this.settings});

  final Game game;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.settings, color: Colors.white70),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => GameMenuDialog(game: game, settings: settings),
        ),
      ),
    );
  }
}

/// The quick settings: what you choose every game. Nothing here changes until
/// Start, so a game in progress can't be reset by accident. Everything rarer
/// is on the other tabs.
class GameMenuDialog extends StatefulWidget {
  const GameMenuDialog({super.key, required this.game, required this.settings});

  final Game game;
  final AppSettings settings;

  @override
  State<GameMenuDialog> createState() => _GameMenuDialogState();
}

class _GameMenuDialogState extends State<GameMenuDialog>
    with SingleTickerProviderStateMixin {
  late int _players = widget.game.playerCount;
  late int _layout = widget.game.layoutIndex;
  late int _life = widget.game.startingLife;

  late final _tabs = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));
  bool get _onNewGame => _tabs.index == 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // Starting over clears the current game, so check first, unless there's
    // nothing to lose yet.
    if (widget.game.hasProgress) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new game?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-start'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    widget.game.newGame(
      playerCount: _players,
      layoutIndex: _layout,
      startingLife: _life,
      startingPlayer: widget.settings.randomStartingPlayer
          ? _random.nextInt(_players)
          : null,
    );
    Navigator.pop(context);
  }

  final _random = Random();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final layouts = tableLayouts[_players]!;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      title: TabBar(
        controller: _tabs,
        // Tighter than the default so three labels fit without cutting off.
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: const [
          Tab(text: 'New game'),
          Tab(text: 'Tracking'),
          Tab(text: 'Sound'),
        ],
      ),
      // New game waits for Start; the other tabs apply as you choose, so they
      // only need closing.
      actions: _onNewGame
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: _start, child: const Text('Start')),
            ]
          : [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
      // Both tabs are laid out, and the dialog takes the size of the larger,
      // so switching tabs never resizes or moves it.
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: IndexedStack(
            index: _tabs.index,
            alignment: AlignmentDirectional.topStart,
            children: [
              _newGame(titleStyle, layouts),
              TrackingSettings(settings: widget.settings),
              SoundSettings(settings: widget.settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _newGame(TextStyle? titleStyle, List<TableLayout> layouts) {
    return Column(
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
        const SizedBox(height: 16),
        // Unlike the choices above, this is remembered straight away; it
        // takes effect each time Start is pressed.
        ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Random starting player'),
            value: widget.settings.randomStartingPlayer,
            onChanged: widget.settings.setRandomStartingPlayer,
          ),
        ),
      ],
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
