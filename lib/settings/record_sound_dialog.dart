import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../sound/sounds.dart';

/// Records a sound: hold the mic to record (up to [maxRecording]), and it
/// plays back on release; the play button beside it plays it again. Pops the
/// kept sound's file name, or null if cancelled.
class RecordSoundDialog extends StatefulWidget {
  const RecordSoundDialog({
    super.key,
    required this.files,
    required this.recorder,
    required this.player,
    required this.name,
  });

  final SoundFiles files;
  final SoundRecorder recorder;
  final SoundPlayer player;

  /// The name it starts with.
  final String name;

  /// Opens the dialog, returning the kept sound's file name, if any.
  static Future<String?> show(BuildContext context, {required String name}) {
    final scope = SoundScope.maybeOf(context)!;
    return showDialog<String>(
      context: context,
      builder: (context) => RecordSoundDialog(
        files: scope.files,
        recorder: scope.recorder,
        player: scope.player,
        name: name,
      ),
    );
  }

  @override
  State<RecordSoundDialog> createState() => _RecordSoundDialogState();
}

class _RecordSoundDialogState extends State<RecordSoundDialog>
    with SingleTickerProviderStateMixin {
  /// Shorter than this is a tap, not a recording.
  static const _tap = Duration(milliseconds: 300);

  late final _name = TextEditingController(text: widget.name);

  /// The ring filling up while recording; only for show; [_limit] and
  /// [_startedAt] do the timing.
  late final _progress = AnimationController(
    vsync: this,
    duration: maxRecording,
  );
  Timer? _limit;
  DateTime? _startedAt;

  /// Whether the microphone may be used; null while asking.
  bool? _permitted;

  /// The file being recorded into, and the last recording finished.
  String? _recording;
  String? _recorded;
  Future<void>? _starting;

  /// Recordings made but not kept, deleted when the dialog closes.
  final _unkept = <String>{};

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    widget.recorder.hasPermission().then((permitted) {
      if (mounted) setState(() => _permitted = permitted);
    });
  }

  @override
  void dispose() {
    if (_recording != null) widget.recorder.cancel();
    _unkept.forEach(widget.files.discard);
    _limit?.cancel();
    _progress.dispose();
    _name.dispose();
    super.dispose();
  }

  void _start() {
    if (_recording != null) return;
    final file = widget.files.newRecording();
    _unkept.add(file);
    setState(() => _recording = file);
    _starting = widget.recorder.start(widget.files.path(file));
    _startedAt = clock.now();
    _limit = Timer(maxRecording, _stop);
    _progress.forward(from: 0);
  }

  Future<void> _stop() async {
    final file = _recording;
    if (file == null) return;
    final held = clock.now().difference(_startedAt!);
    _limit?.cancel();
    _progress.stop();
    setState(() => _recording = null);
    await _starting;
    if (held < _tap) {
      // Too short to be meant: keep the last recording instead.
      await widget.recorder.cancel();
      return;
    }
    await widget.recorder.stop();
    if (!mounted) return;
    setState(() => _recorded = file);
    widget.player.play(SoundChoice.file(file));
  }

  Future<void> _keep() async {
    final file = _recorded!;
    final kept = await widget.files.keepRecording(file, _name.text.trim());
    _unkept.remove(file);
    if (mounted) Navigator.pop(context, kept);
  }

  @override
  Widget build(BuildContext context) {
    if (_permitted == false) {
      return AlertDialog(
        content: const Text('Allow microphone access to record.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    }
    final colors = Theme.of(context).colorScheme;
    final recording = _recording != null;
    final recorded = recording ? null : _recorded;
    final canKeep = recorded != null && _name.text.trim().isNotEmpty;
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The mic, with play beside it once there's something to hear;
          // an empty slot on the other side keeps the mic centred.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: _side),
              _mic(colors, recording: recording),
              SizedBox(
                width: _side,
                child: recorded == null
                    ? null
                    : Align(
                        alignment: Alignment.centerRight,
                        child: IconButton.filledTonal(
                          key: const ValueKey('play-recording'),
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () =>
                              widget.player.play(SoundChoice.file(recorded)),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('recording-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canKeep ? _keep : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  /// The width either side of the mic.
  static const _side = 64.0;

  /// Hold to record; the ring fills as the time runs out.
  Widget _mic(ColorScheme colors, {required bool recording}) {
    return Listener(
      onPointerDown: _permitted == true ? (_) => _start() : null,
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: SizedBox.square(
        key: const ValueKey('record'),
        dimension: 112,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _progress,
              builder: (context, _) => CircularProgressIndicator(
                value: _progress.value,
                strokeWidth: 6,
                color: colors.error,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: recording ? colors.error : colors.primary,
                ),
                child: Icon(
                  Icons.mic,
                  size: 44,
                  color: recording ? colors.onError : colors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
