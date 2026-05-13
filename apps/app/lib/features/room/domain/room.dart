enum RoomState { idle, creating, waiting, joining, connected, error }

class Room {
  final RoomState state;
  final String? roomId;
  final String? errorMessage;

  const Room({
    this.state = RoomState.idle,
    this.roomId,
    this.errorMessage,
  });

  Room copyWith({
    RoomState? state,
    String? roomId,
    String? errorMessage,
  }) {
    return Room(
      state: state ?? this.state,
      roomId: roomId ?? this.roomId,
      errorMessage: errorMessage,
    );
  }
}
