import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/signaling/signal_server_provider.dart';
import '../../../core/webrtc/connection_quality_provider.dart';
import '../../control/domain/input_event.dart' as input;
import '../../control/presentation/control_overlay.dart';
import '../../file_transfer/presentation/file_picker_button.dart';
import '../../file_transfer/presentation/file_transfer_provider.dart';
import '../../file_transfer/presentation/file_transfer_ui.dart';
import '../../screen/presentation/screen_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/connection_status.dart';
import '../domain/session_state.dart';
import 'coordinate_scaler.dart';
import 'session_provider.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const RoomScreen({super.key, required this.role});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _roomIdController = TextEditingController();
  final _scaler = CoordinateScaler();
  Size _widgetSize = Size.zero;

  bool get _isHost => widget.role == UserRole.host;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupFileTransferSave();
      _startSession();
    });
  }

  void _setupFileTransferSave() {
    ref.read(fileTransferProvider.notifier).onSaveFile = (file) async {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir != null) {
        final savePath = '$dir${Platform.pathSeparator}${file.fileName}';
        await File(savePath).writeAsBytes(file.data);
      }
    };
  }

  @override
  void dispose() {
    ref.read(sessionProvider.notifier).disconnect();
    _roomIdController.dispose();
    super.dispose();
  }

  void _startSession() {
    final url = ref.read(signalServerProvider).valueOrNull;
    if (url == null || url.isEmpty) return;

    if (_isHost) {
      ref.read(sessionProvider.notifier).connectAndCreateRoom(url);
    }
  }

  void _joinRoom() {
    final code = _roomIdController.text.trim();
    if (code.isEmpty) return;
    final url = ref.read(signalServerProvider).valueOrNull;
    if (url == null) return;
    ref.read(sessionProvider.notifier).connectAndJoinRoom(url, code);
  }

  void _disconnectAndGoBack() {
    ref.read(connectionQualityProvider.notifier).stop();
    ref.read(sessionProvider.notifier).disconnect();
    ref.read(screenProvider.notifier).stop();
    context.go('/');
  }

  void _sendInputEvent(input.InputEvent event) {
    final renderer = ref.read(screenProvider);
    (double, double) fullScale(double x, double y) {
      if (renderer == null) return (x, y);
      return _scaler.scale(x, y, renderer);
    }
    ref.read(sessionProvider.notifier).sendInputEvent(event, fullScale);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // Client connected with remote stream: fullscreen
    if (!_isHost && session.phase == SessionPhase.connected) {
      return _buildClientFullscreen();
    }

    return Scaffold(
      appBar: _buildAppBar(session),
      body: _buildBody(session),
    );
  }

  // ---------------------------------------------------------------------------
  // Client fullscreen
  // ---------------------------------------------------------------------------

  Widget _buildClientFullscreen() {
    final renderer = ref.watch(screenProvider);
    if (renderer == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: ControlOverlay(
            renderer: renderer,
            onInputEvent: _sendInputEvent,
            onSizeChanged: (size) {
              if (_widgetSize != size) {
                setState(() {
                  _widgetSize = size;
                  _scaler.widgetSize = size;
                });
              }
            },
          ),
        ),
        // Connection quality indicator
        Positioned(
          top: 8,
          left: 8,
          child: _buildQualityIndicator(),
        ),
        // Disconnect button
        Positioned(
          top: 8,
          right: 8,
          child: MouseRegion(
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                onPressed: _disconnectAndGoBack,
              ),
            ),
          ),
        ),
        // File picker button
        Positioned(
          top: 8,
          right: 52,
          child: const FilePickerButton(),
        ),
        // File transfer progress overlay
        const FileTransferOverlay(),
      ],
    );
  }

  Widget _buildQualityIndicator() {
    final stats = ref.watch(connectionQualityProvider);
    final color = switch (stats.quality) {
      ConnectionQuality.excellent => Colors.green,
      ConnectionQuality.good => Colors.orange,
      ConnectionQuality.poor => Colors.red,
      ConnectionQuality.disconnected => Colors.grey,
    };
    final label = switch (stats.quality) {
      ConnectionQuality.excellent => 'Excellent',
      ConnectionQuality.good => 'Good',
      ConnectionQuality.poor => 'Poor',
      ConnectionQuality.disconnected => '...',
    };
    return MouseRegion(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              stats.rttMs > 0 ? '${stats.rttMs}ms' : label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget? _buildAppBar(SessionState session) {
    if (session.phase == SessionPhase.connected && _isHost) {
      return AppBar(
        title: const Text('Sharing Screen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _disconnectAndGoBack,
        ),
        actions: [
          const FilePickerButton(),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ConnectionStatusBadge(
              status: ConnectionStatus.connected,
            ),
          ),
        ],
      );
    }
    return AppBar(
      title: Text(_isHost ? 'Share Screen' : 'Remote Control'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _disconnectAndGoBack,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  Widget _buildBody(SessionState session) {
    if (session.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                session.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  ref.read(sessionProvider.notifier).disconnect();
                  _startSession();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    switch (session.phase) {
      case SessionPhase.connecting:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to server...'),
            ],
          ),
        );

      case SessionPhase.waitingForPeer when _isHost:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Room Code',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  session.roomCode ?? '',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                ),
                const SizedBox(height: 24),
                const Text('Waiting for client to join...'),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        );

      case SessionPhase.waitingForPeer when !_isHost:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _roomIdController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Room Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _joinRoom,
                    child: const Text('Join Room'),
                  ),
                ],
              ),
            ),
          ),
        );

      case SessionPhase.negotiating:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Establishing connection...'),
            ],
          ),
        );

      case SessionPhase.connected when _isHost:
        return Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.screen_share, size: 64, color: Colors.green.shade400),
                  const SizedBox(height: 16),
                  const Text('Screen sharing active', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
            const FileTransferOverlay(),
          ],
        );

      case SessionPhase.connected when !_isHost:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Waiting for stream...'),
            ],
          ),
        );

      case SessionPhase.idle:
        return const Center(child: Text('Disconnected'));

      default:
        return const Center(child: CircularProgressIndicator());
    }
  }
}
