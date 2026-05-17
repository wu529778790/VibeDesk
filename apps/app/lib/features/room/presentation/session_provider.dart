import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/audio/audio_capturer_factory.dart';
import '../../../core/audio/audio_player_factory.dart';
import '../../../core/logger.dart';
import '../../../core/signaling/signaling_client.dart';
import '../../../core/webrtc/screen_capturer.dart';
import '../../../core/webrtc/webrtc_manager.dart';
import '../../clipboard/presentation/clipboard_sync_provider.dart';
import '../../control/domain/input_event.dart' as input;
import '../../control/domain/input_injector.dart';
import '../../control/infra/input_injector_factory.dart';
import '../../file_transfer/presentation/file_transfer_provider.dart';
import '../../settings/presentation/settings_screen.dart' show iceConfigProvider;
import '../domain/session_state.dart';
import 'data_channel_router.dart';

class SessionNotifier extends StateNotifier<SessionState> {
  final Ref _ref;

  SignalingClient? _signaling;
  WebRTCManager? _webrtc;
  ScreenCapturer? _capturer;
  DataChannelRouter? _router;
  AudioCapturer? _audioCapturer;
  AudioPlayer? _audioPlayer;
  StreamSubscription<Uint8List>? _audioSubscription;
  String? _selectedSourceId;

  SessionNotifier(this._ref) : super(const SessionState());

  InputInjector? get inputInjector => _router?.injector;
  WebRTCManager? get webrtc => _webrtc;
  RTCDataChannel? get dataChannel => _webrtc?.dataChannel;

  // ---------------------------------------------------------------------------
  // Host flow
  // ---------------------------------------------------------------------------

  Future<void> connectAndCreateRoom(String url) async {
    state = const SessionState(
      phase: SessionPhase.connecting,
      isHost: true,
    );
    _connectSignaling(url, isHost: true);
  }

  // ---------------------------------------------------------------------------
  // Display selection
  // ---------------------------------------------------------------------------

  Future<List<DisplaySource>> enumerateDisplays() async {
    _capturer ??= ScreenCapturer();
    return _capturer!.enumerateDisplays();
  }

  void selectSource(String sourceId) {
    _selectedSourceId = sourceId;
  }

  // ---------------------------------------------------------------------------
  // Client flow
  // ---------------------------------------------------------------------------

  Future<void> connectAndJoinRoom(String url, String roomCode) async {
    state = SessionState(
      phase: SessionPhase.connecting,
      roomCode: roomCode,
      isHost: false,
    );
    _connectSignaling(url, isHost: false);
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  void disconnect() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _audioCapturer?.stop();
    _audioCapturer?.dispose();
    _audioCapturer = null;
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _capturer?.stop();
    _capturer = null;
    _webrtc?.dispose();
    _webrtc = null;
    _signaling?.dispose();
    _signaling = null;
    _router = null;
    state = const SessionState();
  }

  // ---------------------------------------------------------------------------
  // Signaling
  // ---------------------------------------------------------------------------

  void _connectSignaling(String url, {required bool isHost}) {
    _signaling = SignalingClient(
      onMessage: (msg) => _handleSignalingMessage(msg, isHost),
      onStateChanged: (s) {
        if (s == SignalingState.connected && isHost) {
          _signaling!.send({'type': 'create_room'});
          state = state.copyWith(phase: SessionPhase.waitingForPeer);
        }
      },
      onError: (msg) {
        state = state.copyWith(
          phase: SessionPhase.failed,
          errorMessage: msg,
        );
      },
    );
    _signaling!.connect(url);
  }

  void _handleSignalingMessage(SignalingMessage msg, bool isHost) {
    Logger.info('Signaling message: ${msg.type}');

    switch (msg.type) {
      case 'room_created':
        state = state.copyWith(
          roomCode: msg.data['roomId'] as String,
          phase: SessionPhase.waitingForPeer,
        );

      case 'peer_joined':
        _startHostNegotiation(sourceId: _selectedSourceId);

      case 'room_joined':
        Logger.info('Room joined, waiting for offer...');

      case 'offer':
        _handleOffer(msg.data['sdp'] as String);

      case 'answer':
        _handleAnswer(msg.data['sdp'] as String);

      case 'ice_candidate':
        _handleRemoteIceCandidate(msg.data['candidate']);

      case 'peer_left':
        state = state.copyWith(
          phase: SessionPhase.failed,
          errorMessage: 'Peer disconnected',
        );

      case 'error':
        state = state.copyWith(
          phase: SessionPhase.failed,
          errorMessage: msg.data['message'] as String? ?? 'Unknown error',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Host negotiation
  // ---------------------------------------------------------------------------

  Future<void> _startHostNegotiation({String? sourceId}) async {
    try {
      final iceServers = _ref.read(iceConfigProvider).toMapList();

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
          _ensureRouter();
          channel.onMessage = (m) => _router?.route(m);
        },
        onIceConnectionStateChange: (s) {
          Logger.info('Host: ICE state: $s');
          if (s == RTCIceConnectionState.RTCIceConnectionStateFailed ||
              s == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            state = state.copyWith(
              phase: SessionPhase.failed,
              errorMessage: 'Connection lost',
            );
          }
        },
      );

      await _webrtc!.initialize(iceServers: iceServers);

      _capturer = ScreenCapturer();
      final stream = await _capturer!.captureScreen(sourceId: sourceId);
      await _webrtc!.addLocalStream(stream);

      final dc = await _webrtc!.createDataChannel('control');
      _ensureRouter();

      final (screenW, screenH) = _getScreenSize();
      _router!.injector.setScreenSize(screenW, screenH);
      Logger.info('Host screen size: ${screenW}x$screenH');

      void sendScreenSize() {
        dc.send(RTCDataChannelMessage(jsonEncode({
          'type': 'screen_size',
          'width': screenW,
          'height': screenH,
        })));
      }

      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        sendScreenSize();
        _startClipboardSync(dc);
      }
      dc.onDataChannelState = (s) {
        if (s == RTCDataChannelState.RTCDataChannelOpen) {
          sendScreenSize();
          _startClipboardSync(dc);
        }
      };
      dc.onMessage = (m) => _router?.route(m);

      // Audio capture (Windows only)
      if (Platform.isWindows) {
        try {
          final audioDc = await _webrtc!.createAudioDataChannel();
          _audioCapturer = createAudioCapturer();
          final audioStream = _audioCapturer!.start();
          _audioSubscription = audioStream.listen((chunk) {
            if (audioDc.state == RTCDataChannelState.RTCDataChannelOpen) {
              audioDc.send(RTCDataChannelMessage.fromBinary(chunk));
            }
          });
          Logger.info('Host: audio capture started');
        } catch (e) {
          Logger.error('Host: audio capture failed', e);
        }
      }

      final offer = await _webrtc!.createOffer();
      _signaling?.send({
        'type': 'offer',
        'sdp': offer.sdp,
        'targetPeerId': 'client',
      });
      Logger.info('Host: offer sent');
    } catch (e) {
      Logger.error('Host negotiation failed', e);
      state = state.copyWith(
        phase: SessionPhase.failed,
        errorMessage: 'Failed to start screen sharing: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Client: handle offer
  // ---------------------------------------------------------------------------

  Future<void> _handleOffer(String sdp) async {
    try {
      final iceServers = _ref.read(iceConfigProvider).toMapList();

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
          // Stream is handled by screen_provider in UI layer
        },
        onDataChannel: (channel) {
          Logger.info('Client: data channel received: ${channel.label}');
          channel.onMessage = (m) => _router?.route(m);
          if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
            _startClipboardSync(channel);
          }
          channel.onDataChannelState = (s) {
            if (s == RTCDataChannelState.RTCDataChannelOpen) {
              _startClipboardSync(channel);
            }
          };
        },
        onAudioChannel: (channel) {
          Logger.info('Client: audio data channel received');
          _audioPlayer = createAudioPlayer();
          _audioPlayer!.init(sampleRate: 16000, channels: 1, bitsPerSample: 16);
          channel.onMessage = (message) {
            if (message.isBinary) _audioPlayer!.feed(message.binary);
          };
        },
        onIceConnectionStateChange: (s) {
          Logger.info('Client: ICE state: $s');
          if (s == RTCIceConnectionState.RTCIceConnectionStateFailed ||
              s == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            state = state.copyWith(
              phase: SessionPhase.failed,
              errorMessage: 'Connection lost',
            );
          }
        },
      );

      await _webrtc!.initialize(iceServers: iceServers);
      await _webrtc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

      final answer = await _webrtc!.createAnswer();
      _signaling?.send({
        'type': 'answer',
        'sdp': answer.sdp,
        'targetPeerId': 'host',
      });
      Logger.info('Client: answer sent');

      state = state.copyWith(phase: SessionPhase.negotiating);
    } catch (e) {
      Logger.error('Client handleOffer failed', e);
      state = state.copyWith(
        phase: SessionPhase.failed,
        errorMessage: 'Failed to establish connection: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Host: handle answer
  // ---------------------------------------------------------------------------

  Future<void> _handleAnswer(String sdp) async {
    try {
      await _webrtc?.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      state = state.copyWith(phase: SessionPhase.connected);
      Logger.info('Host: remote description set from answer');
    } catch (e) {
      Logger.error('Host handleAnswer failed', e);
      state = state.copyWith(
        phase: SessionPhase.failed,
        errorMessage: 'Failed to set answer: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ICE candidate
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
    } catch (e) {
      Logger.error('Failed to add ICE candidate', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Input event sending
  // ---------------------------------------------------------------------------

  void sendInputEvent(input.InputEvent event, (double, double) Function(double, double)? scaleFn) {
    final dc = _webrtc?.dataChannel;
    if (dc == null) return;

    if (scaleFn != null &&
        (event is input.MouseMoveEvent ||
            event is input.MouseDownEvent ||
            event is input.MouseUpEvent)) {
      final input.InputEvent scaledEvent;
      if (event is input.MouseMoveEvent) {
        final (x, y) = scaleFn(event.x, event.y);
        scaledEvent = input.MouseMoveEvent(x, y);
      } else if (event is input.MouseDownEvent) {
        final (x, y) = scaleFn(event.x, event.y);
        scaledEvent = input.MouseDownEvent(x, y, event.button);
      } else {
        final up = event as input.MouseUpEvent;
        final (x, y) = scaleFn(up.x, up.y);
        scaledEvent = input.MouseUpEvent(x, y, up.button);
      }
      dc.send(RTCDataChannelMessage(scaledEvent.serialize()));
    } else {
      dc.send(RTCDataChannelMessage(event.serialize()));
    }
  }

  // ---------------------------------------------------------------------------
  // Screen size
  // ---------------------------------------------------------------------------

  void updateHostScreenSize(int width, int height) {
    state = state.copyWith(hostScreenWidth: width, hostScreenHeight: height);
  }

  // ---------------------------------------------------------------------------
  // Clipboard sync
  // ---------------------------------------------------------------------------

  void _startClipboardSync(RTCDataChannel dc) {
    final clipboardNotifier = _ref.read(clipboardSyncProvider.notifier);
    clipboardNotifier.start((text) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(jsonEncode({
          'type': 'clipboard',
          'text': text,
        })));
      }
    });
  }

  void _handleRemoteClipboard(String text) {
    _ref.read(clipboardSyncProvider.notifier).handleRemoteClipboard(text);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _ensureRouter() {
    _router ??= DataChannelRouter(
      injector: createInputInjector(),
      onScreenSize: (w, h) => updateHostScreenSize(w, h),
      onClipboard: (text) => _handleRemoteClipboard(text),
      fileTransferNotifier: _ref.read(fileTransferProvider.notifier),
    );
  }

  (int, int) _getScreenSize() {
    if (Platform.isWindows) {
      try {
        final user32 = ffi.DynamicLibrary.open('user32.dll');
        final getSystemMetrics = user32.lookupFunction<
            ffi.Int32 Function(ffi.Int32),
            int Function(int)>('GetSystemMetrics');
        final w = getSystemMetrics(0);
        final h = getSystemMetrics(1);
        if (w > 0 && h > 0) return (w, h);
      } catch (e) {
        Logger.error('Failed to get screen size via Win32', e);
      }
    } else if (Platform.isMacOS) {
      try {
        final cg = ffi.DynamicLibrary.open(
            '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics');
        final getMainDisplayID =
            cg.lookupFunction<ffi.Uint32 Function(), int Function()>('CGMainDisplayID');
        final getWide = cg.lookupFunction<
            ffi.Int32 Function(ffi.Uint32),
            int Function(int)>('CGDisplayPixelsWide');
        final getHigh = cg.lookupFunction<
            ffi.Int32 Function(ffi.Uint32),
            int Function(int)>('CGDisplayPixelsHigh');
        final id = getMainDisplayID();
        final w = getWide(id);
        final h = getHigh(id);
        if (w > 0 && h > 0) return (w, h);
      } catch (e) {
        Logger.error('Failed to get screen size via CoreGraphics', e);
      }
    }
    return (1920, 1080);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>(
  (ref) => SessionNotifier(ref),
);
