import 'package:record/record.dart';

import 'sounds.dart';

/// Records from the phone's microphone, as AAC in an .m4a file.
class DeviceSoundRecorder implements SoundRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
    path: path,
  );

  @override
  Future<void> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();
}
