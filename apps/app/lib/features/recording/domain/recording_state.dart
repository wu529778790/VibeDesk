enum RecordingStatus { idle, recording, saving }

class RecordingState {
  final RecordingStatus status;
  final Duration? duration;
  final String? filePath;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.duration,
    this.filePath,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    Duration? duration,
    String? filePath,
  }) {
    return RecordingState(
      status: status ?? this.status,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
    );
  }
}
