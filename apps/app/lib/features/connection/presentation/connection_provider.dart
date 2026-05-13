import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/webrtc/webrtc_manager.dart';
import '../../../core/signaling/signaling_client.dart';
import '../../../core/logger.dart';

enum ConnectionState { idle, connecting, connected, failed }

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  late final WebRTCManager _webrtc;
  final SignalingClient _signaling;
  final bool isHost;

  ConnectionNotifier(this._signaling, this.isHost)
      : super(ConnectionState.idle) {
    _webrtc = WebRTCManager(
      onIceCandidate: _onIceCandidate,
      onRemoteStream: (_) {},
      onDataChannel: (_) {},
    );
  }

  WebRTCManager get webrtc => _webrtc;

  Future<void> startNegotiation() async {
    state = ConnectionState.connecting;
    Logger.info(
        'Starting WebRTC negotiation as ${isHost ? "host" : "client"}');

    await _webrtc.initialize(iceServers: [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]);

    if (isHost) {
      final offer = await _webrtc.createOffer();
      _signaling.send({
        'type': 'offer',
        'sdp': offer.sdp,
        'targetPeerId': 'client',
      });
    }
  }

  Future<void> handleOffer(String sdp) async {
    await _webrtc.initialize(iceServers: [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]);
    await _webrtc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await _webrtc.createAnswer();
    _signaling.send({
      'type': 'answer',
      'sdp': answer.sdp,
      'targetPeerId': 'host',
    });
    state = ConnectionState.connected;
  }

  Future<void> handleAnswer(String sdp) async {
    await _webrtc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    state = ConnectionState.connected;
  }

  Future<void> handleIceCandidate(dynamic candidate) async {
    if (candidate != null) {
      await _webrtc.addIceCandidate(RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      ));
    }
  }

  void _onIceCandidate(RTCIceCandidate candidate) {
    _signaling.send({
      'type': 'ice_candidate',
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
      'targetPeerId': isHost ? 'client' : 'host',
    });
  }

  @override
  void dispose() {
    _webrtc.dispose();
    super.dispose();
  }
}
