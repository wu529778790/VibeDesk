import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/webrtc/webrtc_manager.dart';
import '../../../core/webrtc/screen_capturer.dart';
import '../../../core/logger.dart';

class ScreenNotifier extends StateNotifier<RTCVideoRenderer?> {
  final ScreenCapturer _capturer = ScreenCapturer();

  ScreenNotifier() : super(null);

  Future<void> startCapture(WebRTCManager webrtc) async {
    Logger.info('Starting screen capture...');
    final stream = await _capturer.captureScreen();
    await webrtc.addLocalStream(stream);
    Logger.info('Screen capture started');
  }

  void setRemoteRenderer(RTCVideoRenderer renderer) {
    state = renderer;
  }

  WebRTCManager createWebRTCManagerWithRemoteListener() {
    return WebRTCManager(
      onRemoteStream: (stream) {
        Logger.info('Remote stream received');
        final renderer = RTCVideoRenderer();
        renderer.initialize();
        renderer.srcObject = stream;
        state = renderer;
      },
    );
  }

  void stop() {
    _capturer.stop();
    state?.dispose();
    state = null;
  }

  @override
  void dispose() {
    _capturer.stop();
    state?.dispose();
    super.dispose();
  }
}

final screenProvider = StateNotifierProvider<ScreenNotifier, RTCVideoRenderer?>(
  (ref) => ScreenNotifier(),
);
