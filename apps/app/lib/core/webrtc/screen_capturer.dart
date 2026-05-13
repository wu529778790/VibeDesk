import 'package:flutter_webrtc/flutter_webrtc.dart';

class ScreenCapturer {
  MediaStream? _stream;

  Future<MediaStream> captureScreen() async {
    final mediaConstraints = {
      'audio': false,
      'video': {
        'mandatory': {
          'maxWidth': 1920,
          'maxHeight': 1080,
          'maxFrameRate': 30,
        },
      },
    };

    _stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
    return _stream!;
  }

  void stop() {
    _stream?.getTracks().forEach((track) => track.stop());
    _stream?.dispose();
    _stream = null;
  }

  MediaStream? get stream => _stream;
}
