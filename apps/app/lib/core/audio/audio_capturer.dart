import 'dart:typed_data';

abstract class AudioCapturer {
  Stream<Uint8List> start();
  void stop();
  void dispose();
}
