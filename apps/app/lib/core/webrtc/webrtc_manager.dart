import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'ice_candidate_buffer.dart';

class WebRTCManager {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RTCDataChannel? _dataChannel;
  RTCDataChannel? _audioChannel;
  final _iceBuffer = IceCandidateBuffer();
  final void Function(MediaStream)? onRemoteStream;
  final void Function(RTCDataChannel)? onDataChannel;
  final void Function(RTCDataChannel)? onAudioChannel;
  final void Function(RTCIceCandidate)? onIceCandidate;
  final void Function(RTCIceConnectionState)? onIceConnectionStateChange;

  WebRTCManager({
    this.onRemoteStream,
    this.onDataChannel,
    this.onAudioChannel,
    this.onIceCandidate,
    this.onIceConnectionStateChange,
  });

  Future<void> initialize({
    required List<Map<String, dynamic>> iceServers,
  }) async {
    _pc = await createPeerConnection({
      'iceServers': iceServers,
    });

    _pc!.onIceCandidate = (candidate) {
      onIceCandidate?.call(candidate);
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams[0]);
      }
    };

    _pc!.onDataChannel = (channel) {
      if (channel.label == 'audio') {
        _audioChannel = channel;
        onAudioChannel?.call(_audioChannel!);
      } else {
        _dataChannel = channel;
        onDataChannel?.call(_dataChannel!);
      }
    };

    _pc!.onIceConnectionState = (state) {
      onIceConnectionStateChange?.call(state);
    };
  }

  Future<RTCSessionDescription> createOffer({bool iceRestart = false}) async {
    final constraints = <String, dynamic>{
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': true,
    };
    if (iceRestart) {
      constraints['iceRestart'] = true;
    }
    final desc = await _pc!.createOffer(constraints);
    await _pc!.setLocalDescription(desc);
    return desc;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final desc = await _pc!.createAnswer();
    await _pc!.setLocalDescription(desc);
    return desc;
  }

  Future<void> setRemoteDescription(RTCSessionDescription desc) async {
    await _pc!.setRemoteDescription(desc);
    // Drain any candidates that arrived before the remote description
    for (final c in _iceBuffer.drain()) {
      await _pc!.addCandidate(c);
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (!_iceBuffer.add(candidate)) {
      await _pc!.addCandidate(candidate);
    }
  }

  Future<void> addLocalStream(MediaStream stream) async {
    _localStream = stream;
    for (final track in stream.getTracks()) {
      await _pc!.addTrack(track, stream);
    }
  }

  Future<RTCDataChannel> createDataChannel(String label) async {
    _dataChannel = await _pc!.createDataChannel(
        label, RTCDataChannelInit()..ordered = true);
    return _dataChannel!;
  }

  Future<RTCDataChannel> createAudioDataChannel() async {
    _audioChannel = await _pc!.createDataChannel('audio',
        RTCDataChannelInit()..ordered = false..maxRetransmits = 0);
    return _audioChannel!;
  }

  RTCDataChannel? get dataChannel => _dataChannel;
  RTCDataChannel? get audioChannel => _audioChannel;
  RTCPeerConnection? get peerConnection => _pc;

  void dispose() {
    _audioChannel?.close();
    _localStream?.dispose();
    _pc?.close();
    _pc = null;
  }
}
