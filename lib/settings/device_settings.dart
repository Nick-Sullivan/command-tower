import 'package:flutter/material.dart';

import '../sound/sounds.dart';
import '../widgets/skull.dart';
import 'app_settings.dart';

/// How the phone behaves: sound, vibration and keeping the screen on, then a
/// sound for each moment: losing life, gaining life, and a player being
/// knocked out. Picking a sound plays it.
class DeviceSettings extends StatelessWidget {
  const DeviceSettings({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        Widget row(SoundRole role, Widget icon) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _SoundChoice(
            key: ValueKey(('sound', role.name)),
            role: role,
            icon: icon,
            enabled: settings.soundOn,
            selected: settings.sound(role),
            onSelected: (s) => settings.setSound(role, s),
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibration'),
              value: settings.vibration,
              onChanged: settings.setVibration,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep screen on'),
              value: settings.keepScreenOn,
              onChanged: settings.setKeepScreenOn,
            ),
            // Sound sits directly above the sounds it turns on.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sound'),
              value: settings.soundOn,
              onChanged: settings.setSoundOn,
            ),
            // Always shown, so turning sound on doesn't resize the dialog;
            // greyed out until it's on.
            row(SoundRole.minus, const Icon(Icons.remove)),
            row(SoundRole.plus, const Icon(Icons.add)),
            row(SoundRole.knockedOut, const _SkullIcon()),
          ],
        );
      },
    );
  }
}

/// The skull at icon size, in the surrounding icon colour (so it greys out
/// with the field).
class _SkullIcon extends StatelessWidget {
  const _SkullIcon();

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final size = icon.size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Skull(size: size * 0.85, color: icon.color ?? Colors.black),
      ),
    );
  }
}

class _SoundChoice extends StatelessWidget {
  const _SoundChoice({
    super.key,
    required this.role,
    required this.icon,
    required this.enabled,
    required this.selected,
    required this.onSelected,
  });

  final SoundRole role;

  /// What the row is for: −, + or a skull, shown inside the field.
  final Widget icon;
  final bool enabled;
  final Sound selected;
  final ValueChanged<Sound> onSelected;

  @override
  Widget build(BuildContext context) {
    // A dropdown rather than chips: each row has many sounds, and chips for
    // all of them made the dialog taller than the screen.
    return DropdownMenu<Sound>(
      // Rebuilt when the choice changes, so it always shows it.
      key: ValueKey(selected),
      enabled: enabled,
      leadingIcon: icon,
      initialSelection: selected,
      expandedInsets: EdgeInsets.zero,
      requestFocusOnTap: false,
      dropdownMenuEntries: [
        for (final sound in Sound.forRole(role))
          DropdownMenuEntry(value: sound, label: sound.label),
      ],
      onSelected: (sound) {
        if (sound == null) return;
        onSelected(sound);
        SoundScope.maybeOf(context)?.player.play(sound);
      },
    );
  }
}
