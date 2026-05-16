import 'dart:io';
import 'dart:typed_data';
import 'audio_player.dart';
import 'macos_audio_player.dart';

AudioPlayer createAudioPlayer() {
  if (Platform.isMacOS) {
    return MacosAudioPlayer();
  }
  return _NoOpAudioPlayer();
}

class _NoOpAudioPlayer extends AudioPlayer {
  @override
  void init({required int sampleRate, required int channels, required int bitsPerSample}) {}
  @override
  void feed(Uint8List pcmChunk) {}
  @override
  void stop() {}
  @override
  void dispose() {}
}
