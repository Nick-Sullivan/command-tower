import 'package:flutter/material.dart';

import '../sound/sounds.dart';
import '../widgets/skull.dart';
import 'app_settings.dart';
import 'record_sound_dialog.dart';

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
            choices: settings.soundChoices(role),
            icon: icon,
            enabled: settings.soundOn,
            selected: settings.sound(role),
            onSelected: (s) => settings.setSound(role, s),
            onImported: (file) {
              settings.addImportedSound(file);
              settings.setSound(role, SoundChoice.file(file));
            },
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

/// One row's sound: a dropdown of its choices, with "Import…" and "Record…"
/// last to add a sound file from the phone or the microphone. Picking a sound
/// plays it.
class _SoundChoice extends StatefulWidget {
  const _SoundChoice({
    super.key,
    required this.choices,
    required this.icon,
    required this.enabled,
    required this.selected,
    required this.onSelected,
    required this.onImported,
  });

  final List<SoundChoice> choices;

  /// What the row is for: −, + or a skull, shown inside the field.
  final Widget icon;
  final bool enabled;
  final SoundChoice selected;
  final ValueChanged<SoundChoice> onSelected;
  final ValueChanged<String> onImported;

  @override
  State<_SoundChoice> createState() => _SoundChoiceState();
}

class _SoundChoiceState extends State<_SoundChoice> {
  /// Stands in for the "Import…" entry; never saved or played.
  static const _import = SoundChoice.file('\u0000import');

  /// Likewise "Record…".
  static const _record = SoundChoice.file('\u0000record');

  /// Bumped to redraw the field after an import, so a cancelled one goes back
  /// to showing the current sound.
  int _redraws = 0;

  Future<void> _importSound() async {
    final scope = SoundScope.maybeOf(context);
    if (scope == null) return;
    try {
      final file = await scope.files.import();
      if (file != null) {
        widget.onImported(file);
        scope.player.play(SoundChoice.file(file));
      }
    } on SoundTooBig {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('That file is too big. Pick one under 2 MB.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    if (mounted) setState(() => _redraws++);
  }

  Future<void> _recordSound() async {
    final scope = SoundScope.maybeOf(context);
    if (scope == null) return;
    final labels = {for (final c in widget.choices) c.label};
    var n = 1;
    while (labels.contains('Recording $n')) {
      n++;
    }
    final file = await RecordSoundDialog.show(context, name: 'Recording $n');
    if (file != null) {
      widget.onImported(file);
      scope.player.play(SoundChoice.file(file));
    }
    if (mounted) setState(() => _redraws++);
  }

  @override
  Widget build(BuildContext context) {
    // A dropdown rather than chips: each row has many sounds, and chips for
    // all of them made the dialog taller than the screen.
    return DropdownMenu<SoundChoice>(
      // Rebuilt when the choice changes, so it always shows it.
      key: ValueKey((widget.selected, _redraws)),
      enabled: widget.enabled,
      leadingIcon: widget.icon,
      initialSelection: widget.selected,
      expandedInsets: EdgeInsets.zero,
      requestFocusOnTap: false,
      dropdownMenuEntries: [
        for (final sound in widget.choices)
          DropdownMenuEntry(value: sound, label: sound.label),
        const DropdownMenuEntry(
          value: _import,
          label: 'Import…',
          leadingIcon: Icon(Icons.upload_file),
        ),
        const DropdownMenuEntry(
          value: _record,
          label: 'Record…',
          leadingIcon: Icon(Icons.mic),
        ),
      ],
      onSelected: (sound) {
        if (sound == null) return;
        if (sound == _import) {
          _importSound();
          return;
        }
        if (sound == _record) {
          _recordSound();
          return;
        }
        widget.onSelected(sound);
        SoundScope.maybeOf(context)?.player.play(sound);
      },
    );
  }
}
