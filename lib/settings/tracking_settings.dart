import 'package:flutter/material.dart';

import '../game/counters.dart';
import '../widgets/counter_icon.dart';
import '../widgets/crossed_swords.dart';
import 'app_settings.dart';

/// A chip per thing you can track; selected ones appear on every panel.
/// Changes apply straight away and never reset the game.
class TrackingSettings extends StatelessWidget {
  const TrackingSettings({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final on = settings.counters;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: Builder(
                builder: (context) => CrossedSwords(
                  size: 18,
                  color: IconTheme.of(context).color ?? Colors.black,
                ),
              ),
              showCheckmark: false,
              label: const Text('Commander damage'),
              selected: settings.commanderDamage,
              onSelected: settings.setCommanderDamage,
            ),
            for (final c in Counter.values)
              FilterChip(
                avatar: Icon(counterIcons[c], size: 18),
                showCheckmark: false,
                label: Text(c.label),
                selected: on.contains(c),
                onSelected: (selected) => settings.setCounter(c, selected),
              ),
          ],
        );
      },
    );
  }
}
