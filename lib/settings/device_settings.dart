import 'package:flutter/material.dart';

import '../sound/sounds.dart';
import '../widgets/skull.dart';
import 'app_settings.dart';
import 'record_sound_dialog.dart';

/// How the phone behaves: sound, vibration and keeping the screen on, then
/// the sounds for each moment: losing life, gaining life, and a player being
/// knocked out. Ticking a sound plays it.
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
          child: _SoundsField(
            key: ValueKey(('sound', role.name)),
            choices: settings.soundChoices(role),
            icon: icon,
            enabled: settings.soundOn,
            selected: settings.sounds(role),
            onChanged: (s, on) => settings.setSound(role, s, on: on),
            onImported: (file) {
              settings.addImportedSound(file);
              settings.setSound(role, SoundChoice.file(file));
            },
            onDeleted: (file) {
              settings.removeImportedSound(file);
              SoundScope.maybeOf(context)?.files.discard(file);
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

/// One row's sounds: a field showing the ones ticked, which opens a list to
/// tick any number of them (one plays at random each time), with "Import…"
/// and "Record…" last to add a sound from the phone or the microphone.
/// Ticking a sound plays it.
class _SoundsField extends StatefulWidget {
  const _SoundsField({
    super.key,
    required this.choices,
    required this.icon,
    required this.enabled,
    required this.selected,
    required this.onChanged,
    required this.onImported,
    required this.onDeleted,
  });

  final List<SoundChoice> choices;

  /// What the row is for: −, + or a skull, shown inside the field.
  final Widget icon;
  final bool enabled;
  final List<SoundChoice> selected;
  final void Function(SoundChoice sound, bool on) onChanged;
  final ValueChanged<String> onImported;

  /// An imported (or recorded) sound's file, deleted.
  final ValueChanged<String> onDeleted;

  @override
  State<_SoundsField> createState() => _SoundsFieldState();
}

class _SoundsFieldState extends State<_SoundsField> {
  final _menu = MenuController();

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
  }

  /// Deletes an imported sound, once the player confirms: there's no undo.
  Future<void> _deleteSound(SoundChoice sound) async {
    _menu.close();
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${sound.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete ?? false) widget.onDeleted(sound.file!);
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
  }

  @override
  Widget build(BuildContext context) {
    // A field with a list rather than chips: each row has many sounds, and
    // chips for all of them made the dialog taller than the screen.
    final selected = widget.selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The list is as wide as the field: each entry is that wide.
        final width = constraints.maxWidth;
        final entry = ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(width, 48)),
        );
        return _menuAnchor(selected, width, entry);
      },
    );
  }

  Widget _menuAnchor(
    List<SoundChoice> selected,
    double width,
    ButtonStyle entry,
  ) {
    return MenuAnchor(
      controller: _menu,
      style: MenuStyle(maximumSize: WidgetStatePropertyAll(Size(width, 360))),
      menuChildren: [
        for (final sound in widget.choices)
          CheckboxMenuButton(
            style: entry,
            value: selected.contains(sound),
            // Stays open, to tick several.
            closeOnActivate: false,
            onChanged: (on) {
              widget.onChanged(sound, on ?? false);
              if (on ?? false) {
                SoundScope.maybeOf(context)?.player.play(sound);
              }
            },
            // Imported and recorded sounds can be deleted, right there.
            trailingIcon: sound.file == null
                ? null
                : IconButton(
                    key: ValueKey(('delete-sound', sound.file!)),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteSound(sound),
                  ),
            child: Text(sound.label),
          ),
        MenuItemButton(
          style: entry,
          leadingIcon: const Icon(Icons.upload_file),
          onPressed: _importSound,
          child: const Text('Import…'),
        ),
        MenuItemButton(
          style: entry,
          leadingIcon: const Icon(Icons.mic),
          onPressed: _recordSound,
          child: const Text('Record…'),
        ),
      ],
      builder: (context, menu, _) => InkWell(
        onTap: widget.enabled
            ? () => menu.isOpen ? menu.close() : menu.open()
            : null,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          isFocused: menu.isOpen,
          decoration: InputDecoration(
            enabled: widget.enabled,
            border: const OutlineInputBorder(),
            prefixIcon: widget.icon,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            selected.isEmpty
                ? Sound.none.label
                : [for (final s in selected) s.label].join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
