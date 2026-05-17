import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/signaling/signal_server_provider.dart';
import 'auth_provider.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final serverUrl = ref.watch(signalServerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Logged in as ${auth.email ?? "unknown"}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('Device: ${auth.deviceId ?? "unknown"}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            const Text('Quick Connect',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Connect to your other devices automatically. '
              'Make sure both devices are logged in with the same account and online.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: serverUrl != null && serverUrl.isNotEmpty
                  ? () => _autoConnect(context, ref, serverUrl)
                  : null,
              icon: const Icon(Icons.screen_share),
              label: const Text('Share Screen'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: serverUrl != null && serverUrl.isNotEmpty
                  ? () => context.go('/room?role=client')
                  : null,
              icon: const Icon(Icons.computer),
              label: const Text('Remote Control'),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => context.go('/'),
              child: const Text('Use room code instead'),
            ),
          ],
        ),
      ),
    );
  }

  void _autoConnect(BuildContext context, WidgetRef ref, String serverUrl) {
    context.go('/room?role=host');
  }
}
