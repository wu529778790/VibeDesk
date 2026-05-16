import 'dart:typed_data';

abstract class AudioPlayer {
  void init({
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  });
  void feed(Uint8List pcmChunk);
  void stop();
  void dispose();
}
