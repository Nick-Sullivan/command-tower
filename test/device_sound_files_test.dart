import 'dart:io';

import 'package:command_tower/sound/device_sound_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DeviceSoundFiles files;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sounds');
    files = DeviceSoundFiles(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> record() async {
    final file = files.newRecording();
    await File(files.path(file)).writeAsString('clip');
    return file;
  }

  test('a kept recording is named, never over another sound', () async {
    expect(await files.keepRecording(await record(), 'Ouch'), 'Ouch.m4a');
    expect(await files.keepRecording(await record(), 'Ouch'), 'Ouch (2).m4a');
    // Only the kept sounds are left: the recordings were moved, not copied.
    expect(dir.listSync().map((f) => f.uri.pathSegments.last).toSet(), {
      'Ouch.m4a',
      'Ouch (2).m4a',
    });
  });

  test('names lose characters a file name can\'t have', () {
    expect(DeviceSoundFiles.safeFileName('a/b:c?'), 'abc');
    expect(DeviceSoundFiles.safeFileName('..hidden'), 'hidden');
    expect(DeviceSoundFiles.safeFileName(' /?* '), 'Recording');
  });

  test('recordings left behind are cleared, kept sounds aren\'t', () async {
    await files.keepRecording(await record(), 'Ouch');
    final left = await record();
    await files.discardUnkept();
    expect(File(files.path(left)).existsSync(), isFalse);
    expect(File(files.path('Ouch.m4a')).existsSync(), isTrue);
  });

  test('a discarded recording is deleted', () async {
    final file = await record();
    await files.discard(file);
    expect(File(files.path(file)).existsSync(), isFalse);
    // Discarding what's already gone is fine.
    await files.discard(file);
  });
}
