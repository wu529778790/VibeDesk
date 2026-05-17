import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class DisplaySource {
  final String id;
  final String name;
  final dynamic thumbnail;

  const DisplaySource({required this.id, required this.name, this.thumbnail});
}

class ScreenCapturer {
  MediaStream? _stream;

  Future<List<DisplaySource>> enumerateDisplays() async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux)) {
      final sources = await desktopCapturer.getSources(
        types: [SourceType.Screen],
      );
      return sources
          .map((s) => DisplaySource(id: s.id, name: s.name, thumbnail: s.thumbnail))
          .toList();
    }
    return [];
  }

  Future<MediaStream> captureScreen({String? sourceId}) async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux)) {
      String? deviceId = sourceId;
      if (deviceId == null) {
        final sources = await desktopCapturer.getSources(
          types: [SourceType.Screen],
        );
        if (sources.isEmpty) throw Exception('No screen source found');
        deviceId = sources.first.id;
      }

      _stream = await navigator.mediaDevices.getDisplayMedia({
        'audio': true,
        'video': {
          'deviceId': {'exact': deviceId},
          'mandatory': {
            'maxWidth': 1920,
            'maxHeight': 1080,
            'maxFrameRate': 30,
          },
        },
      });
    } else {
      _stream = await navigator.mediaDevices.getDisplayMedia({
        'audio': true,
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
