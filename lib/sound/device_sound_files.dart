import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'sounds.dart';

/// Imported sounds, copied into a "sounds" folder in the app's own storage.
class DeviceSoundFiles implements SoundFiles {
  DeviceSoundFiles(this._dir);

  final Directory _dir;

  static Future<DeviceSoundFiles> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sounds');
    await dir.create(recursive: true);
    final files = DeviceSoundFiles(dir);
    await files.discardUnkept();
    return files;
  }

  /// Deletes recordings that were never kept, left behind if the app closed
  /// while recording.
  Future<void> discardUnkept() async {
    await for (final f in _dir.list()) {
      final name = f.uri.pathSegments.last;
      if (f is File && name.startsWith(_recordingPrefix)) await f.delete();
    }
  }

  static const _recordingPrefix = '.recording-';

  @override
  String path(String file) => '${_dir.path}/$file';

  @override
  Future<String?> import() async {
    final picked = await FilePicker.pickFiles(type: FileType.audio);
    final source = picked?.files.singleOrNull;
    final sourcePath = source?.path;
    if (source == null || sourcePath == null) return null;
    if (source.size > maxBytes) throw const SoundTooBig();
    final name = _unusedName(source.name);
    await File(sourcePath).copy(path(name));
    return name;
  }

  @override
  String newRecording() =>
      '$_recordingPrefix${DateTime.now().microsecondsSinceEpoch}.wav';

  @override
  Future<String> keepRecording(String file, String name) async {
    final kept = _unusedName('${safeFileName(name)}.wav');
    await File(path(file)).rename(path(kept));
    return kept;
  }

  @override
  Future<void> discard(String file) async {
    final f = File(path(file));
    if (await f.exists()) await f.delete();
  }

  /// [name] without characters a file name can't have; "Recording" if
  /// nothing's left.
  static String safeFileName(String name) {
    final safe = name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '').trim();
    // A leading dot would hide the file, like a recording in progress.
    final visible = safe.replaceFirst(RegExp(r'^\.+'), '');
    return visible.isEmpty ? 'Recording' : visible;
  }

  /// [name], or "name (2).mp3" and so on if that's taken.
  String _unusedName(String name) {
    if (!File(path(name)).existsSync()) return name;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    for (var n = 2; ; n++) {
      final candidate = '$base ($n)$ext';
      if (!File(path(candidate)).existsSync()) return candidate;
    }
  }
}
