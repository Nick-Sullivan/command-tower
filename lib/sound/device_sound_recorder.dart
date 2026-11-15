import 'dart:io';

import 'package:record/record.dart';

import 'sounds.dart';
import 'wav_trim.dart';

/// Records from the phone's microphone, as a WAV file with the quiet start
/// (before the player makes their sound) cut off.
class DeviceSoundRecorder implements SoundRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.wav,
      numChannels: 1,
      sampleRate: 44100,
    ),
    path: path,
  );

  @override
  Future<void> stop() async {
    final path = await _recorder.stop();
    if (path == null) return;
    final file = File(path);
    final trimmed = trimLeadingSilence(await file.readAsBytes());
    await file.writeAsBytes(trimmed, flush: true);
  }

  @override
  Future<void> cancel() => _recorder.cancel();
}
