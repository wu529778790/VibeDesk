import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/user_role.dart';
import '../../../core/logger.dart';
import '../../../core/signaling/signal_server_provider.dart';
import '../../../core/signaling/signaling_client.dart';
import '../../settings/presentation/settings_screen.dart' show iceConfigProvider;
import '../../../core/webrtc/screen_capturer.dart';
import '../../../core/webrtc/webrtc_manager.dart';
import '../../control/domain/input_event.dart' as input;
import '../../control/domain/input_injector.dart';
import '../../control/infra/input_injector_factory.dart';
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
  final _roomIdController = TextEditingController();

  // Core instances owned by this widget
  SignalingClient? _signaling;
  WebRTCManager? _webrtc;
  ScreenCapturer? _capturer;
  InputInjector? _inputInjector;

  // UI state
  SignalingState _signalingState = SignalingState.disconnected;
  ConnectionStatus _connectionStatus = ConnectionStatus.idle;
  String? _roomCode;
  String? _errorMessage;
  bool _hasRemoteStream = false;

  // Host screen size (used by client for coordinate scaling)
  int _hostScreenWidth = 1920;
  int _hostScreenHeight = 1080;

  bool get _isHost => widget.role == UserRole.host;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectSignaling());
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _capturer?.stop();
    _inputInjector?.dispose();
    _webrtc?.dispose();
    _signaling?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Win32 screen size
  // ---------------------------------------------------------------------------

  (int, int) _getWin32ScreenSize() {
    if (!Platform.isWindows) return (1920, 1080);
    try {
      // Use dart:ffi to call GetSystemMetrics
      final user32 = DynamicLibrary.open('user32.dll');
      final getSystemMetrics = user32.lookupFunction<
          Int32 Function(Int32),
          int Function(int)>('GetSystemMetrics');
      // SM_CXSCREEN = 0, SM_CYSCREEN = 1
      final width = getSystemMetrics(0);
      final height = getSystemMetrics(1);
      if (width > 0 && height > 0) return (width, height);
    } catch (e) {
      Logger.error('Failed to get screen size via Win32', e);
    }
    return (1920, 1080);
  }

  // ---------------------------------------------------------------------------
  // Signaling
  // ---------------------------------------------------------------------------

  void _connectSignaling() {
    final url = ref.read(signalServerProvider).valueOrNull;
    if (url == null || url.isEmpty) return;

    _signaling = SignalingClient(
      onMessage: _handleSignalingMessage,
      onStateChanged: (state) {
        setState(() => _signalingState = state);

        if (state == SignalingState.connected && _isHost) {
          _signaling!.send({'type': 'create_room'});
          setState(() {
            _connectionStatus = ConnectionStatus.connecting;
          });
        }
      },
      onError: (msg) {
        setState(() {
          _connectionStatus = ConnectionStatus.failed;
          _errorMessage = msg;
        });
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
        _startHostNegotiation();

      case 'room_joined':
        Logger.info('Room joined, waiting for offer...');

      case 'offer':
        _handleOffer(msg.data['sdp'] as String);

      case 'answer':
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
      _roomCode = code;
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
        onDataChannel: (channel) {
          Logger.info('Host: data channel received: ${channel.label}');
          _inputInjector = createInputInjector();
          channel.onMessage = _handleDataChannelMessage;
        },
        onIceConnectionStateChange: (state) {
          Logger.info('Host: ICE connection state: $state');
          if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
              state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            setState(() {
              _connectionStatus = ConnectionStatus.failed;
              _errorMessage = 'Connection lost';
            });
          }
        },
      );

      await _webrtc!.initialize(iceServers: iceServers);

      // Capture screen and add as local stream
      _capturer = ScreenCapturer();
      final stream = await _capturer!.captureScreen();
      await _webrtc!.addLocalStream(stream);

      // Create data channel for input events
      final dc = await _webrtc!.createDataChannel('control');
      _inputInjector = createInputInjector();

      // Get host screen size and configure injector
      final (screenW, screenH) = _getWin32ScreenSize();
      _inputInjector!.setScreenSize(screenW, screenH);
      Logger.info('Host screen size: ${screenW}x$screenH');

      // Send screen size to client when channel is ready
      Future.delayed(const Duration(seconds: 1), () {
        if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
          dc.send(RTCDataChannelMessage(jsonEncode({
            'type': 'screen_size',
            'width': screenW,
            'height': screenH,
          })));
        }
      });

      dc.onMessage = _handleDataChannelMessage;

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
        onRemoteStream: (stream) async {
          Logger.info('Client: remote stream received');
          final renderer = RTCVideoRenderer();
          await renderer.initialize();
          renderer.srcObject = stream;
          ref.read(screenProvider.notifier).setRemoteRenderer(renderer);
          setState(() {
            _hasRemoteStream = true;
            _connectionStatus = ConnectionStatus.connected;
          });
        },
        onDataChannel: (channel) {
          Logger.info('Client: data channel received: ${channel.label}');
          channel.onMessage = _handleDataChannelMessage;
        },
        onIceConnectionStateChange: (state) {
          Logger.info('Client: ICE connection state: $state');
          if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
              state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            setState(() {
              _connectionStatus = ConnectionStatus.failed;
              _errorMessage = 'Connection lost';
            });
          }
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
  // DataChannel input handling
  // ---------------------------------------------------------------------------

  void _sendInputEvent(input.InputEvent event) {
    final dc = _webrtc?.dataChannel;
    if (dc == null) return;

    // Scale coordinates from widget space to host screen space
    if (event is input.MouseMoveEvent) {
      final scaled = _scaleCoordinates(event.x, event.y);
      dc.send(RTCDataChannelMessage(input.MouseMoveEvent(
        scaled.$1,
        scaled.$2,
      ).serialize()));
    } else if (event is input.MouseDownEvent) {
      final scaled = _scaleCoordinates(event.x, event.y);
      dc.send(RTCDataChannelMessage(input.MouseDownEvent(
        scaled.$1,
        scaled.$2,
        event.button,
      ).serialize()));
    } else if (event is input.MouseUpEvent) {
      final scaled = _scaleCoordinates(event.x, event.y);
      dc.send(RTCDataChannelMessage(input.MouseUpEvent(
        scaled.$1,
        scaled.$2,
        event.button,
      ).serialize()));
    } else {
      dc.send(RTCDataChannelMessage(event.serialize()));
    }
  }

  /// Scale widget-local coordinates to host screen coordinates.
  /// Uses the video renderer's actual size as the source coordinate space.
  (double, double) _scaleCoordinates(double widgetX, double widgetY) {
    final renderer = ref.read(screenProvider);
    if (renderer == null) return (widgetX, widgetY);

    // Get the actual video frame size from the renderer
    final videoWidth = renderer.videoWidth.toDouble();
    final videoHeight = renderer.videoHeight.toDouble();
    if (videoWidth <= 0 || videoHeight <= 0) return (widgetX, widgetY);

    // Scale: widget coords → video coords → host screen coords
    // Step 1: widgetX/Y is relative to the widget size
    // Step 2: map to video pixel coordinates
    // Step 3: map to host screen coordinates
    //
    // Since RTCVideoView uses objectFit=contain, the video is centered
    // with possible letterboxing. We need to account for that.
    //
    // For simplicity, assume the widget fills with the video's aspect ratio
    // (contain mode). The actual rendered video area within the widget
    // maintains the aspect ratio.
    //
    // The widget size is the ControlOverlay size. The video is rendered
    // inside it with objectFit=contain. We need the actual widget size
    // to compute the mapping. But we don't have direct access here.
    //
    // Simplified approach: the video frame maps linearly to the host screen.
    // widgetX/widgetY are in widget coordinates. We assume the widget
    // closely matches the video aspect ratio (Flutter's RTCVideoView with
    // contain fills as much as possible).
    //
    // Direct mapping: widget coords → host screen coords
    final hostX = (widgetX / videoWidth * _hostScreenWidth).round();
    final hostY = (widgetY / videoHeight * _hostScreenHeight).round();

    return (hostX.toDouble(), hostY.toDouble());
  }

  void _handleDataChannelMessage(RTCDataChannelMessage message) {
    try {
      final json = jsonDecode(message.text) as Map<String, dynamic>;
      final type = json['type'] as String?;

      // Handle screen_size message (client receives from host)
      if (type == 'screen_size') {
        _hostScreenWidth = (json['width'] as num?)?.toInt() ?? 1920;
        _hostScreenHeight = (json['height'] as num?)?.toInt() ?? 1080;
        Logger.info(
            'Received host screen size: ${_hostScreenWidth}x$_hostScreenHeight');
        return;
      }

      if (type == null || _inputInjector == null) return;

      final x = (json['x'] as num?)?.toInt() ?? 0;
      final y = (json['y'] as num?)?.toInt() ?? 0;

      switch (type) {
        case 'mouse_move':
          _inputInjector!.mouseMove(x, y);
        case 'mouse_down':
          final button = _parseMouseButton(json['button'] as String);
          _inputInjector!.mouseDown(x, y, button);
        case 'mouse_up':
          final button = _parseMouseButton(json['button'] as String);
          _inputInjector!.mouseUp(x, y, button);
        case 'key_down':
          final key = json['key'] as String? ?? '';
          final modifiers = _parseModifiers(json['modifiers']);
          _inputInjector!.keyDown(key, modifiers);
        case 'key_up':
          final key = json['key'] as String? ?? '';
          final modifiers = _parseModifiers(json['modifiers']);
          _inputInjector!.keyUp(key, modifiers);
      }
    } catch (e) {
      Logger.error('Failed to handle data channel message', e);
    }
  }

  input.MouseButton _parseMouseButton(String? name) {
    switch (name) {
      case 'right':
        return input.MouseButton.right;
      case 'middle':
        return input.MouseButton.middle;
      default:
        return input.MouseButton.left;
    }
  }

  List<input.ModifierKey> _parseModifiers(dynamic modifiers) {
    if (modifiers is! List) return [];
    return modifiers.map((m) {
      switch (m) {
        case 'shift':
          return input.ModifierKey.shift;
        case 'ctrl':
          return input.ModifierKey.ctrl;
        case 'alt':
          return input.ModifierKey.alt;
        case 'meta':
          return input.ModifierKey.meta;
        default:
          return input.ModifierKey.shift;
      }
    }).toList();
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _disconnectAndGoBack,
        ),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _disconnectAndGoBack,
      ),
    );
  }

  void _disconnectAndGoBack() {
    _capturer?.stop();
    _capturer = null;
    _webrtc?.dispose();
    _webrtc = null;
    _signaling?.dispose();
    _signaling = null;
    ref.read(screenProvider.notifier).stop();
    context.go('/');
  }

  Widget _buildBody() {
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

    if (_signalingState == SignalingState.disconnected) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Reconnecting...'),
          ],
        ),
      );
    }

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
      _hostScreenWidth = 1920;
      _hostScreenHeight = 1080;
    });
    _connectSignaling();
  }
}
