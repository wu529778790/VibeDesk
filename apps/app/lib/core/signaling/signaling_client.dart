import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SignalingState { disconnected, connecting, connected }

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

  SignalingClient({
    required this.onMessage,
    required this.onStateChanged,
  });

  SignalingState get state => _state;

  void connect(String url) {
    _state = SignalingState.connecting;
    onStateChanged(_state);
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen(
      (event) {
        if (_state != SignalingState.connected) {
          _state = SignalingState.connected;
          onStateChanged(_state);
        }
        final json = jsonDecode(event as String) as Map<String, dynamic>;
        onMessage(SignalingMessage.fromJson(json));
      },
      onError: (_) => _disconnect(),
      onDone: () => _disconnect(),
    );
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void _disconnect() {
    _state = SignalingState.disconnected;
    onStateChanged(_state);
    _channel = null;
  }

  void dispose() {
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
