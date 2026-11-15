import 'dart:typed_data';

import 'package:command_tower/sound/wav_trim.dart';
import 'package:flutter_test/flutter_test.dart';

/// A mono 16-bit WAV at 1000 samples a second, so a sample is a millisecond.
Uint8List _wav(List<int> samples, {int sampleRate = 1000}) {
  final out = ByteData(44 + samples.length * 2);
  void id(int at, String s) {
    for (var i = 0; i < 4; i++) {
      out.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  id(0, 'RIFF');
  out.setUint32(4, 36 + samples.length * 2, Endian.little);
  id(8, 'WAVE');
  id(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little);
  out.setUint16(22, 1, Endian.little);
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, sampleRate * 2, Endian.little);
  out.setUint16(32, 2, Endian.little);
  out.setUint16(34, 16, Endian.little);
  id(36, 'data');
  out.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    out.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return out.buffer.asUint8List();
}

List<int> _samples(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  return [
    for (var at = 44; at < wav.length; at += 2)
      data.getInt16(at, Endian.little),
  ];
}

void main() {
  test('cuts the quiet start, keeping a moment before the sound', () {
    // 500 ms of hiss, then the sound.
    final hiss = [for (var i = 0; i < 500; i++) i.isEven ? 30 : -30];
    final sound = [for (var i = 0; i < 200; i++) i.isEven ? 20000 : -20000];
    final trimmed = trimLeadingSilence(_wav([...hiss, ...sound]));
    final kept = _samples(trimmed);
    // 15 ms of lead-in, then all of the sound.
    expect(kept, hasLength(15 + 200));
    expect(kept.sublist(15), sound);
  });

  test('a sound from the very start, or no sound at all, is left alone', () {
    final loud = _wav([20000, -20000, 100, 50]);
    expect(trimLeadingSilence(loud), loud);
    final silent = _wav(List.filled(100, 0));
    expect(trimLeadingSilence(silent), silent);
    // Only hiss, with the odd blip in it: nothing to trim to.
    final hiss = _wav([for (var i = 0; i < 300; i++) i == 200 ? 40 : 5]);
    expect(trimLeadingSilence(hiss), hiss);
  });

  test('anything but a 16-bit WAV is left alone', () {
    final notWav = Uint8List.fromList(List.filled(64, 7));
    expect(trimLeadingSilence(notWav), notWav);
  });
}
