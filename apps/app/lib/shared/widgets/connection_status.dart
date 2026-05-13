import 'package:flutter/material.dart';

enum ConnectionStatus { idle, connecting, connected, failed }

class ConnectionStatusBadge extends StatelessWidget {
  final ConnectionStatus status;
  const ConnectionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color,
          ),
        ),
        const SizedBox(width: 6),
        Text(_label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Color get _color => switch (status) {
        ConnectionStatus.idle => Colors.grey,
        ConnectionStatus.connecting => Colors.orange,
        ConnectionStatus.connected => Colors.green,
        ConnectionStatus.failed => Colors.red,
      };

  String get _label => switch (status) {
        ConnectionStatus.idle => 'Disconnected',
        ConnectionStatus.connecting => 'Connecting...',
        ConnectionStatus.connected => 'Connected',
        ConnectionStatus.failed => 'Failed',
      };
}
