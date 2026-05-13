import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/room.dart';
import '../../../core/signaling/signaling_client.dart';
import '../../../core/logger.dart';

class RoomNotifier extends StateNotifier<Room> {
  late final SignalingClient _signaling;
  final bool isHost;

  RoomNotifier(this.isHost) : super(const Room()) {
    _signaling = SignalingClient(
      onMessage: _handleMessage,
      onStateChanged: _handleState,
    );
  }

  void connect(String serverUrl) {
    Logger.info('Connecting to signaling server: $serverUrl');
    _signaling.connect(serverUrl);
  }

  void createRoom() {
    Logger.info('Creating room...');
    state = state.copyWith(state: RoomState.creating);
    _signaling.send({'type': 'create_room'});
  }

  void joinRoom(String roomId) {
    Logger.info('Joining room: $roomId');
    state = state.copyWith(state: RoomState.joining, roomId: roomId);
    _signaling.send({'type': 'join_room', 'roomId': roomId});
  }

  void _handleMessage(SignalingMessage msg) {
    Logger.info('Signaling message: ${msg.type}');
    switch (msg.type) {
      case 'room_created':
        state = state.copyWith(
          state: RoomState.waiting,
          roomId: msg.data['roomId'] as String,
        );
      case 'room_joined':
        state = state.copyWith(state: RoomState.connected);
      case 'peer_joined':
        state = state.copyWith(state: RoomState.connected);
      case 'peer_left':
        state = state.copyWith(
          state: RoomState.error,
          errorMessage: 'Peer disconnected',
        );
      case 'error':
        state = state.copyWith(
          state: RoomState.error,
          errorMessage: msg.data['message'] as String,
        );
    }
  }

  void _handleState(SignalingState s) {
    Logger.info('Signaling state: $s');
  }

  SignalingClient get signaling => _signaling;

  @override
  void dispose() {
    _signaling.dispose();
    super.dispose();
  }
}
