import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class ScreenCapturer {
  MediaStream? _stream;

  Future<MediaStream> captureScreen() async {
    // On desktop, enumerate sources and pick the first screen
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux)) {
      final sources = await desktopCapturer.getSources(
        types: [SourceType.Screen],
      );
      if (sources.isEmpty) {
        throw Exception('No screen source found');
      }

      _stream = await navigator.mediaDevices.getDisplayMedia({
        'audio': false,
        'video': {
          'deviceId': {'exact': sources.first.id},
          'mandatory': {
            'maxWidth': 1920,
            'maxHeight': 1080,
            'maxFrameRate': 30,
          },
        },
      });
    } else {
      _stream = await navigator.mediaDevices.getDisplayMedia({
        'audio': false,
        'video': {
          'mandatory': {
            'maxWidth': 1920,
            'maxHeight': 1080,
            'maxFrameRate': 30,
          },
        },
      });
    }

    return _stream!;
  }

  void stop() {
    _stream?.getTracks().forEach((track) => track.stop());
    _stream?.dispose();
    _stream = null;
  }

  MediaStream? get stream => _stream;
}
