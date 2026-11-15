import 'dart:typed_data';

/// Cuts the quiet start off a recording: everything before the sound gets
/// loud enough (a share of its loudest moment), less a moment's lead-in so
/// the start of the sound itself isn't clipped.
///
/// [wav] is a 16-bit PCM WAV file; anything else, or a recording that never
/// gets louder than [minPeak] (out of 32767), comes back unchanged.
Uint8List trimLeadingSilence(
  Uint8List wav, {
  double threshold = 0.15,
  int minPeak = 500,
  Duration leadIn = const Duration(milliseconds: 15),
}) {
  final pcm = _Wav.parse(wav);
  if (pcm == null) return wav;
  final samples = pcm.samples;
  var peak = 0;
  for (final s in samples) {
    if (s.abs() > peak) peak = s.abs();
  }
  // Nothing louder than background hiss: no sound to find the start of.
  if (peak < minPeak) return wav;
  final loud = peak * threshold;
  final first = samples.indexWhere((s) => s.abs() >= loud);
  // Whole frames (a sample per channel), less the lead-in.
  final frame =
      (first ~/ pcm.channels) -
      pcm.sampleRate * leadIn.inMicroseconds ~/ Duration.microsecondsPerSecond;
  if (frame <= 0) return wav;
  return pcm.withSamplesFrom(frame * pcm.channels);
}

/// The parts of a WAV file needed to trim it.
class _Wav {
  _Wav(this.channels, this.sampleRate, this.samples);

  final int channels;
  final int sampleRate;
  final Int16List samples;

  static _Wav? parse(Uint8List bytes) {
    if (bytes.length < 12) return null;
    final data = ByteData.sublistView(bytes);
    String id(int at) => String.fromCharCodes(bytes, at, at + 4);
    if (id(0) != 'RIFF' || id(8) != 'WAVE') return null;
    int? channels, sampleRate, bits;
    var at = 12;
    while (at + 8 <= bytes.length) {
      final chunk = id(at);
      var size = data.getUint32(at + 4, Endian.little);
      final body = at + 8;
      if (chunk == 'fmt ' && body + 16 <= bytes.length) {
        final format = data.getUint16(body, Endian.little);
        if (format != 1) return null; // Not plain PCM.
        channels = data.getUint16(body + 2, Endian.little);
        sampleRate = data.getUint32(body + 4, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
      } else if (chunk == 'data') {
        if (channels == null || sampleRate == null || bits != 16) return null;
        // A recorder stopped early may not have filled in the size.
        if (size == 0 || body + size > bytes.length) size = bytes.length - body;
        final count = size ~/ 2;
        final samples = Int16List(count);
        for (var i = 0; i < count; i++) {
          samples[i] = data.getInt16(body + i * 2, Endian.little);
        }
        return _Wav(channels, sampleRate, samples);
      }
      at = body + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }

  /// A plain WAV file of the samples from [start] on.
  Uint8List withSamplesFrom(int start) {
    final kept = samples.sublist(start);
    final dataSize = kept.length * 2;
    final out = ByteData(44 + dataSize);
    void id(int at, String s) {
      for (var i = 0; i < 4; i++) {
        out.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    id(0, 'RIFF');
    out.setUint32(4, 36 + dataSize, Endian.little);
    id(8, 'WAVE');
    id(12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little);
    out.setUint16(22, channels, Endian.little);
    out.setUint32(24, sampleRate, Endian.little);
    out.setUint32(28, sampleRate * channels * 2, Endian.little);
    out.setUint16(32, channels * 2, Endian.little);
    out.setUint16(34, 16, Endian.little);
    id(36, 'data');
    out.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < kept.length; i++) {
      out.setInt16(44 + i * 2, kept[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }
}
