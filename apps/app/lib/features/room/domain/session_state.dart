enum SessionPhase {
  idle,
  connecting,
  waitingForPeer,
  negotiating,
  connected,
  failed,
}

class SessionState {
  final SessionPhase phase;
  final String? roomCode;
  final String? errorMessage;
  final bool isHost;
  final int hostScreenWidth;
  final int hostScreenHeight;

  const SessionState({
    this.phase = SessionPhase.idle,
    this.roomCode,
    this.errorMessage,
    this.isHost = true,
    this.hostScreenWidth = 1920,
    this.hostScreenHeight = 1080,
  });

  SessionState copyWith({
    SessionPhase? phase,
    String? roomCode,
    String? errorMessage,
    bool? isHost,
    int? hostScreenWidth,
    int? hostScreenHeight,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      roomCode: roomCode ?? this.roomCode,
      errorMessage: errorMessage,
      isHost: isHost ?? this.isHost,
      hostScreenWidth: hostScreenWidth ?? this.hostScreenWidth,
      hostScreenHeight: hostScreenHeight ?? this.hostScreenHeight,
    );
  }
}
