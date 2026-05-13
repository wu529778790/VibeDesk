import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../app.dart' show UserRole;
import '../../../core/logger.dart';
import '../../../core/signaling/signaling_client.dart';
import '../../../core/webrtc/screen_capturer.dart';
import '../../../core/webrtc/webrtc_manager.dart';
import '../../../features/settings/presentation/settings_screen.dart'
    show iceConfigProvider;
import '../../control/domain/input_event.dart' as input;
import '../../control/presentation/control_overlay.dart';
import '../../screen/presentation/screen_provider.dart';
import '../../../shared/widgets/connection_status.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const RoomScreen({super.key, required this.role});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  // Controllers
  final _serverController = TextEditingController(text: 'ws://localhost:3000');
  final _roomIdController = TextEditingController();

  // Core instances owned by this widget
  SignalingClient? _signaling;
  WebRTCManager? _webrtc;
  ScreenCapturer? _capturer;

  // UI state
  SignalingState _signalingState = SignalingState.disconnected;
  ConnectionStatus _connectionStatus = ConnectionStatus.idle;
  String? _roomCode;
  String? _errorMessage;
  bool _hasRemoteStream = false;

  bool get _isHost => widget.role == UserRole.host;

  @override
  void dispose() {
    _serverController.dispose();
    _roomIdController.dispose();
    _capturer?.stop();
    _webrtc?.dispose();
    _signaling?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Signaling
  // ---------------------------------------------------------------------------

  void _connectSignaling() {
    final url = _serverController.text.trim();
    if (url.isEmpty) return;

    _signaling = SignalingClient(
      onMessage: _handleSignalingMessage,
      onStateChanged: (state) {
        setState(() => _signalingState = state);

        // Once signaling is connected, host sends create_room
        if (state == SignalingState.connected && _isHost) {
          _signaling!.send({'type': 'create_room'});
          setState(() {
            _connectionStatus = ConnectionStatus.connecting;
          });
        }
      },
    );

    _signaling!.connect(url);
    setState(() {
      _connectionStatus = ConnectionStatus.connecting;
      _errorMessage = null;
    });
  }

  void _handleSignalingMessage(SignalingMessage msg) {
    Logger.info('Signaling message: ${msg.type}');

    switch (msg.type) {
      case 'room_created':
        setState(() {
          _roomCode = msg.data['roomId'] as String;
        });

      case 'peer_joined':
        // Host receives this when a client joins — start WebRTC negotiation
        _startHostNegotiation();

      case 'room_joined':
        // Client successfully joined, wait for offer
        Logger.info('Room joined, waiting for offer...');

      case 'offer':
        // Client receives offer from host
        _handleOffer(msg.data['sdp'] as String);

      case 'answer':
        // Host receives answer from client
        _handleAnswer(msg.data['sdp'] as String);

      case 'ice_candidate':
        _handleRemoteIceCandidate(msg.data['candidate']);

      case 'peer_left':
        setState(() {
          _connectionStatus = ConnectionStatus.failed;
          _errorMessage = 'Peer disconnected';
        });

      case 'error':
        setState(() {
          _connectionStatus = ConnectionStatus.failed;
          _errorMessage = msg.data['message'] as String? ?? 'Unknown error';
        });
    }
  }

  // ---------------------------------------------------------------------------
  // Client: join room
  // ---------------------------------------------------------------------------

  void _joinRoom() {
    final code = _roomIdController.text.trim();
    if (code.isEmpty) return;
    _signaling!.send({'type': 'join_room', 'roomId': code});
    setState(() {
      _connectionStatus = ConnectionStatus.connecting;
    });
  }

  // ---------------------------------------------------------------------------
  // Host WebRTC flow
  // ---------------------------------------------------------------------------

  Future<void> _startHostNegotiation() async {
    try {
      final iceServers = ref.read(iceConfigProvider).toMapList();

      _webrtc = WebRTCManager(
        onIceCandidate: (candidate) {
          _signaling?.send({
            'type': 'ice_candidate',
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            'targetPeerId': 'client',
          });
        },
        onRemoteStream: (_) {},
        onDataChannel: (_) {},
      );

      await _webrtc!.initialize(iceServers: iceServers);

      // Capture screen and add as local stream
      _capturer = ScreenCapturer();
      final stream = await _capturer!.captureScreen();
      await _webrtc!.addLocalStream(stream);

      // Create data channel for input events
      await _webrtc!.createDataChannel('control');

      // Create and send offer
      final offer = await _webrtc!.createOffer();
      _signaling?.send({
        'type': 'offer',
        'sdp': offer.sdp,
        'targetPeerId': 'client',
      });

      Logger.info('Host: offer sent');
    } catch (e) {
      Logger.error('Host negotiation failed', e);
      setState(() {
        _connectionStatus = ConnectionStatus.failed;
        _errorMessage = 'Failed to start screen sharing: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Client WebRTC flow
  // ---------------------------------------------------------------------------

  Future<void> _handleOffer(String sdp) async {
    try {
      final iceServers = ref.read(iceConfigProvider).toMapList();

      _webrtc = WebRTCManager(
        onIceCandidate: (candidate) {
          _signaling?.send({
            'type': 'ice_candidate',
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            'targetPeerId': 'host',
          });
        },
        onRemoteStream: (stream) {
          Logger.info('Client: remote stream received');
          final renderer = RTCVideoRenderer();
          renderer.initialize();
          renderer.srcObject = stream;
          ref.read(screenProvider.notifier).setRemoteRenderer(renderer);
          setState(() {
            _hasRemoteStream = true;
            _connectionStatus = ConnectionStatus.connected;
          });
        },
        onDataChannel: (channel) {
          Logger.info('Client: data channel received: ${channel.label}');
        },
      );

      await _webrtc!.initialize(iceServers: iceServers);

      // Set remote description (offer)
      await _webrtc!.setRemoteDescription(
        RTCSessionDescription(sdp, 'offer'),
      );

      // Create and send answer
      final answer = await _webrtc!.createAnswer();
      _signaling?.send({
        'type': 'answer',
        'sdp': answer.sdp,
        'targetPeerId': 'host',
      });

      Logger.info('Client: answer sent');
    } catch (e) {
      Logger.error('Client handleOffer failed', e);
      setState(() {
        _connectionStatus = ConnectionStatus.failed;
        _errorMessage = 'Failed to establish connection: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Answer handling (host)
  // ---------------------------------------------------------------------------

  Future<void> _handleAnswer(String sdp) async {
    try {
      await _webrtc?.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
      setState(() {
        _connectionStatus = ConnectionStatus.connected;
      });
      Logger.info('Host: remote description set from answer');
    } catch (e) {
      Logger.error('Host handleAnswer failed', e);
      setState(() {
        _connectionStatus = ConnectionStatus.failed;
        _errorMessage = 'Failed to set answer: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // ICE candidate handling
  // ---------------------------------------------------------------------------

  Future<void> _handleRemoteIceCandidate(dynamic candidateData) async {
    if (candidateData == null || _webrtc == null) return;
    try {
      final map = candidateData as Map<String, dynamic>;
      await _webrtc!.addIceCandidate(
        RTCIceCandidate(
          map['candidate'] as String?,
          map['sdpMid'] as String?,
          map['sdpMLineIndex'] as int?,
        ),
      );
      Logger.info('Remote ICE candidate added');
    } catch (e) {
      Logger.error('Failed to add ICE candidate', e);
    }
  }

  // ---------------------------------------------------------------------------
  // DataChannel input sending
  // ---------------------------------------------------------------------------

  void _sendInputEvent(input.InputEvent event) {
    final dc = _webrtc?.dataChannel;
    if (dc != null) {
      dc.send(RTCDataChannelMessage(event.serialize()));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_connectionStatus == ConnectionStatus.connected && _isHost) {
      return AppBar(
        title: const Text('Sharing Screen'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ConnectionStatusBadge(status: _connectionStatus),
          ),
        ],
      );
    }
    return AppBar(
      title: Text(_isHost ? 'Share Screen' : 'Remote Control'),
    );
  }

  Widget _buildBody() {
    // Error state
    if (_errorMessage != null) {
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _reset,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Not connected to signaling — show server URL input
    if (_signalingState == SignalingState.disconnected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _isHost ? Icons.screen_share : Icons.settings_remote,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  _isHost ? 'Share Your Screen' : 'Remote Control',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: 'Signal Server URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _connectSignaling,
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Connecting to signaling
    if (_signalingState == SignalingState.connecting) {
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
    }

    // Signaling connected — role-specific UI
    return _buildConnectedBody();
  }

  Widget _buildConnectedBody() {
    // Host: waiting for client
    if (_isHost && _roomCode != null && _connectionStatus != ConnectionStatus.connected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Room Code',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _roomCode!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Waiting for client to join...',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    // Host: connected and sharing
    if (_isHost && _connectionStatus == ConnectionStatus.connected) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.screen_share,
                size: 64, color: Colors.green.shade400),
            const SizedBox(height: 16),
            const Text(
              'Screen sharing active',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Client: need to enter room code
    if (!_isHost && _roomCode == null && !_hasRemoteStream) {
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
    }

    // Client: waiting for stream
    if (!_isHost && !_hasRemoteStream) {
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
    }

    // Client: showing remote stream with control overlay
    if (!_isHost && _hasRemoteStream) {
      final renderer = ref.watch(screenProvider);
      if (renderer == null) {
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
      }
      return Container(
        color: Colors.black,
        child: ControlOverlay(
          renderer: renderer,
          onInputEvent: _sendInputEvent,
        ),
      );
    }

    // Fallback
    return const Center(child: Text('Unexpected state'));
  }

  void _reset() {
    _capturer?.stop();
    _capturer = null;
    _webrtc?.dispose();
    _webrtc = null;
    _signaling?.dispose();
    _signaling = null;
    ref.read(screenProvider.notifier).stop();
    setState(() {
      _signalingState = SignalingState.disconnected;
      _connectionStatus = ConnectionStatus.idle;
      _roomCode = null;
      _errorMessage = null;
      _hasRemoteStream = false;
    });
  }
}
