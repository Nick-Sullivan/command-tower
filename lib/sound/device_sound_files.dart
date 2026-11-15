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
    return DeviceSoundFiles(dir);
  }

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
