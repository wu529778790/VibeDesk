import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signaling_client.dart';

const _kServerUrlKey = 'signal_server_url';
const defaultSignalServerUrl = 'wss://signal.vibedesk.app';

// ---------------------------------------------------------------------------
// Persistent server URL
// ---------------------------------------------------------------------------

class SignalServerNotifier extends StateNotifier<AsyncValue<String>> {
  SignalServerNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_kServerUrlKey) ?? defaultSignalServerUrl;
    state = AsyncValue.data(url);
  }

  Future<void> setUrl(String url) async {
    state = AsyncValue.data(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerUrlKey, url);
  }
}

final signalServerProvider =
    StateNotifierProvider<SignalServerNotifier, AsyncValue<String>>((ref) {
  return SignalServerNotifier();
});

// ---------------------------------------------------------------------------
// Signal connection state
// ---------------------------------------------------------------------------

enum SignalConnectionStatus { idle, connecting, connected, failed }

class SignalConnectionState {
  final SignalConnectionStatus status;
  final String? error;

  const SignalConnectionState({
    this.status = SignalConnectionStatus.idle,
    this.error,
  });
}

class SignalConnectionNotifier extends StateNotifier<SignalConnectionState> {
  SignalingClient? _client;
  final void Function(String url)? onConnected;

  SignalConnectionNotifier({this.onConnected})
      : super(const SignalConnectionState());

  bool get isConnected => state.status == SignalConnectionStatus.connected;
  SignalingClient? get client => _client;

  void connect(String url) {
    if (state.status == SignalConnectionStatus.connecting) return;

    _client?.dispose();
    _client = SignalingClient(
      onMessage: (_) {},
      onStateChanged: (s) {
        switch (s) {
          case SignalingState.connected:
            state = const SignalConnectionState(
                status: SignalConnectionStatus.connected);
            onConnected?.call(url);
          case SignalingState.connecting:
            state = const SignalConnectionState(
                status: SignalConnectionStatus.connecting);
          case SignalingState.error:
            state = const SignalConnectionState(
                status: SignalConnectionStatus.failed,
                error: 'Connection failed');
          case SignalingState.disconnected:
            state = const SignalConnectionState(
                status: SignalConnectionStatus.failed,
                error: 'Disconnected');
        }
      },
      onError: (msg) {
        state =
            SignalConnectionState(status: SignalConnectionStatus.failed, error: msg);
      },
    );
    _client!.connect(url);
    state = const SignalConnectionState(
        status: SignalConnectionStatus.connecting);
  }

  void disconnect() {
    _client?.dispose();
    _client = null;
    state = const SignalConnectionState();
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }
}

final signalConnectionProvider =
    StateNotifierProvider<SignalConnectionNotifier, SignalConnectionState>(
        (ref) {
  return SignalConnectionNotifier();
});
