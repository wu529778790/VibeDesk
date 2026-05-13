import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Buffers ICE candidates that arrive before the remote description is set.
///
/// This solves a race condition in WebRTC signaling: ICE candidates can
/// arrive via the signaling channel before `setRemoteDescription` has been
/// called on the peer connection. The native WebRTC layer throws if
/// `addCandidate` is called before the remote description is set.
///
/// Usage:
/// 1. Call [add] with each incoming ICE candidate
/// 2. Call [drain] after `setRemoteDescription` succeeds
/// 3. After draining, call [addDirect] for subsequent candidates
class IceCandidateBuffer {
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pending = [];

  bool get isReady => _remoteDescriptionSet;
  int get pendingCount => _pending.length;

  /// Add a candidate. Returns true if buffered, false if it should be
  /// passed directly to the peer connection.
  bool add(RTCIceCandidate candidate) {
    if (_remoteDescriptionSet) {
      return false;
    }
    _pending.add(candidate);
    return true;
  }

  /// Drain all buffered candidates. Call this after setRemoteDescription.
  List<RTCIceCandidate> drain() {
    _remoteDescriptionSet = true;
    final candidates = List<RTCIceCandidate>.from(_pending);
    _pending.clear();
    return candidates;
  }

  void reset() {
    _remoteDescriptionSet = false;
    _pending.clear();
  }
}
