import 'dart:io';
import 'audio_capturer.dart';
import 'win32_audio_capturer.dart';

AudioCapturer createAudioCapturer() {
  if (Platform.isWindows) {
    return Win32AudioCapturer();
  }
  return _NoOpAudioCapturer();
}

class _NoOpAudioCapturer extends AudioCapturer {
  @override
  Stream<Never> start() => const Stream.empty();
  @override
  void stop() {}
  @override
  void dispose() {}
}
