import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCManager {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RTCDataChannel? _dataChannel;
  final void Function(MediaStream)? onRemoteStream;
  final void Function(RTCDataChannel)? onDataChannel;
  final void Function(RTCIceCandidate)? onIceCandidate;

  WebRTCManager({
    this.onRemoteStream,
    this.onDataChannel,
    this.onIceCandidate,
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
      _dataChannel = channel;
      onDataChannel?.call(_dataChannel!);
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    final desc = await _pc!.createOffer({
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': false,
    });
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
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _pc!.addCandidate(candidate);
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

  RTCDataChannel? get dataChannel => _dataChannel;

  void dispose() {
    _localStream?.dispose();
    _pc?.close();
    _pc = null;
  }
}
