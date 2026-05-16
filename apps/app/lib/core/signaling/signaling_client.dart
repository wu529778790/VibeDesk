import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SignalingState { disconnected, connecting, connected, error }

class SignalingMessage {
  final String type;
  final Map<String, dynamic> data;

  SignalingMessage(this.type, this.data);

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(json['type'] as String, json);
  }

  Map<String, dynamic> toJson() => data;
}

class SignalingClient {
  WebSocketChannel? _channel;
  SignalingState _state = SignalingState.disconnected;
  final void Function(SignalingMessage) onMessage;
  final void Function(SignalingState) onStateChanged;
  final void Function(String)? onError;

  // Reconnect state
  String? _lastUrl;
  Timer? _reconnectTimer;
  int _reconnectDelay = 1;
  static const _maxReconnectDelay = 30;
  bool _intentionalDisconnect = false;

  SignalingClient({
    required this.onMessage,
    required this.onStateChanged,
    this.onError,
  });

  SignalingState get state => _state;

  void connect(String url) {
    _intentionalDisconnect = false;
    _lastUrl = url;
    _reconnectDelay = 1;
    _reconnectTimer?.cancel();
    _doConnect(url);
  }

  void _doConnect(String url) {
    _state = SignalingState.connecting;
    onStateChanged(_state);
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.ready.then((_) {
      _state = SignalingState.connected;
      _reconnectDelay = 1;
      onStateChanged(_state);
    }).catchError((error) {
      _state = SignalingState.error;
      onStateChanged(_state);
      onError?.call('Connection failed: $error');
      _scheduleReconnect();
    });

    _channel!.stream.listen(
      (event) {
        final json = jsonDecode(event as String) as Map<String, dynamic>;
        onMessage(SignalingMessage.fromJson(json));
      },
      onError: (error) {
        _handleDisconnect('Connection error: $error');
      },
      onDone: () {
        if (_state == SignalingState.connected) {
          _handleDisconnect('Connection closed');
        }
      },
    );
  }

  void _handleDisconnect(String reason) {
    _state = SignalingState.disconnected;
    onStateChanged(_state);
    _channel = null;
    onError?.call(reason);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _lastUrl == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      if (_lastUrl != null && !_intentionalDisconnect) {
        onError?.call('Reconnecting in ${_reconnectDelay}s...');
        _doConnect(_lastUrl!);
        _reconnectDelay = (_reconnectDelay * 2).clamp(1, _maxReconnectDelay);
      }
    });
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void dispose() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _state = SignalingState.disconnected;
  }
}

final signalingClientProvider = Provider<SignalingClient>((ref) {
  return SignalingClient(
    onMessage: (_) {},
    onStateChanged: (_) {},
  );
});
