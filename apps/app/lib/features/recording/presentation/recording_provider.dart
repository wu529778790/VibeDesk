import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/recording_state.dart';

class RecordingNotifier extends StateNotifier<RecordingState> {
  MediaRecorder? _recorder;
  Timer? _timer;
  DateTime? _startTime;

  RecordingNotifier() : super(const RecordingState());

  Future<void> startRecording(MediaStreamTrack videoTrack, String outputPath) async {
    _recorder = MediaRecorder();
    await _recorder!.start(outputPath, videoTrack: videoTrack);
    _startTime = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime != null) {
        state = state.copyWith(
          duration: DateTime.now().difference(_startTime!),
        );
      }
    });

    state = RecordingState(
      status: RecordingStatus.recording,
      filePath: outputPath,
    );
  }

  Future<void> stopRecording() async {
    _timer?.cancel();
    _timer = null;

    if (_recorder != null) {
      state = state.copyWith(status: RecordingStatus.saving);
      await _recorder!.stop();
      _recorder = null;
    }

    state = state.copyWith(status: RecordingStatus.idle);
    _startTime = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder?.stop();
    super.dispose();
  }
}

final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>(
  (ref) => RecordingNotifier(),
);
