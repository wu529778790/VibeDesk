import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum ConnectionQuality { excellent, good, poor, disconnected }

class ConnectionStats {
  final int rttMs;
  final double packetLoss;
  final int availableBitrate;
  final ConnectionQuality quality;

  const ConnectionStats({
    required this.rttMs,
    required this.packetLoss,
    required this.availableBitrate,
    required this.quality,
  });
}

class ConnectionQualityNotifier extends StateNotifier<ConnectionStats> {
  RTCPeerConnection? _pc;
  Timer? _timer;

  ConnectionQualityNotifier()
      : super(const ConnectionStats(
          rttMs: 0,
          packetLoss: 0,
          availableBitrate: 0,
          quality: ConnectionQuality.disconnected,
        ));

  void attach(RTCPeerConnection pc) {
    _pc = pc;
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _poll(),
    );
  }

  Future<void> _poll() async {
    if (_pc == null) return;
    try {
      final reports = await _pc!.getStats();
      int rtt = 0;
      int packetsSent = 0;
      int packetsLost = 0;
      int bitrate = 0;

      for (final report in reports) {
        final v = report.values;
        final type = report.type;
        if (type == 'candidate-pair' && v['selected'] == true) {
          rtt = (v['currentRoundTripTime'] as num?)?.toInt() ?? 0;
          bitrate = (v['availableOutgoingBitrate'] as num?)?.toInt() ?? 0;
          rtt = (rtt * 1000).round();
        }
        if (type == 'outbound-rtp' && v['kind'] == 'video') {
          packetsSent = (v['packetsSent'] as num?)?.toInt() ?? 0;
          packetsLost = (v['packetsLost'] as num?)?.toInt() ?? 0;
        }
      }
      final loss =
          packetsSent > 0 ? packetsLost / packetsSent : 0.0;

      ConnectionQuality quality;
      if (rtt == 0 && packetsSent == 0) {
        quality = ConnectionQuality.disconnected;
      } else if (rtt < 100 && loss < 0.02) {
        quality = ConnectionQuality.excellent;
      } else if (rtt < 250 && loss < 0.05) {
        quality = ConnectionQuality.good;
      } else {
        quality = ConnectionQuality.poor;
      }

      state = ConnectionStats(
        rttMs: rtt,
        packetLoss: loss,
        availableBitrate: bitrate,
        quality: quality,
      );
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _pc = null;
    state = const ConnectionStats(
      rttMs: 0,
      packetLoss: 0,
      availableBitrate: 0,
      quality: ConnectionQuality.disconnected,
    );
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final connectionQualityProvider =
    StateNotifierProvider<ConnectionQualityNotifier, ConnectionStats>(
  (ref) => ConnectionQualityNotifier(),
);
