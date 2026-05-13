import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app.dart' show UserRole;
import '../domain/room.dart';
import 'room_provider.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const RoomScreen({super.key, required this.role});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _serverController = TextEditingController(text: 'ws://localhost:3000');
  final _roomIdController = TextEditingController();
  bool _connected = false;

  @override
  void dispose() {
    _serverController.dispose();
    _roomIdController.dispose();
    super.dispose();
  }

  void _connect() {
    final notifier = ref.read(roomProvider(widget.role).notifier);
    notifier.connect(_serverController.text);
    setState(() => _connected = true);
    if (widget.role == UserRole.host) {
      // Will send create_room once signaling is connected
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider(widget.role));
    final isHost = widget.role == UserRole.host;

    return Scaffold(
      appBar: AppBar(
        title: Text(isHost ? 'Share Screen' : 'Remote Control'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_connected) ...[
                  TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: 'Signal Server URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _connect,
                    child: const Text('Connect'),
                  ),
                ],

                if (_connected && room.state == RoomState.waiting) ...[
                  const Text(
                    'Room Code',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    room.roomId ?? '',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Waiting for client to join...',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],

                if (_connected && !isHost && room.state == RoomState.idle) ...[
                  TextField(
                    controller: _roomIdController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Room Code',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(roomProvider(widget.role).notifier)
                          .joinRoom(_roomIdController.text);
                    },
                    child: const Text('Join Room'),
                  ),
                ],

                if (room.state == RoomState.joining) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  const Text('Joining room...', textAlign: TextAlign.center),
                ],

                if (room.state == RoomState.connected) ...[
                  const Icon(Icons.check_circle, size: 48, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text('Connected! Starting WebRTC...'),
                ],

                if (room.state == RoomState.error) ...[
                  Icon(Icons.error, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    room.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Provider for room state
final roomProvider =
    StateNotifierProvider.family<RoomNotifier, Room, UserRole>(
  (ref, role) {
    return RoomNotifier(role == UserRole.host);
  },
);
