import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/platform/auto_launch_service.dart';
import '../../../core/signaling/signal_server_provider.dart';
import '../../clipboard/presentation/clipboard_sync_provider.dart';
import '../domain/ice_config.dart';

final iceConfigProvider = StateProvider<IceConfig>((ref) => const IceConfig());

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _serverController;
  bool _autoLaunch = false;

  @override
  void initState() {
    super.initState();
    final url = ref.read(signalServerProvider).valueOrNull ?? '';
    _serverController = TextEditingController(text: url);
    _autoLaunch = AutoLaunchService.isEnabled;
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  void _saveAndReconnect() {
    final url = _serverController.text.trim();
    if (url.isEmpty) return;

    ref.read(signalServerProvider.notifier).setUrl(url);
    ref.read(signalConnectionProvider.notifier).connect(url);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved and connecting...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(iceConfigProvider);
    final connStatus = ref.watch(signalConnectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Signal Server
          const Text(
            'Signal Server',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _serverController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.dns),
              hintText: 'wss://signal.vibedesk.app',
            ),
          ),
          const SizedBox(height: 8),
          if (connStatus.status == SignalConnectionStatus.connected)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
                  const SizedBox(width: 6),
                  Text('Connected', style: TextStyle(color: Colors.green.shade400, fontSize: 13)),
                ],
              ),
            )
          else if (connStatus.status == SignalConnectionStatus.failed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.error, size: 16, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      connStatus.error ?? 'Connection failed',
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else if (connStatus.status == SignalConnectionStatus.connecting)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 6),
                  Text('Connecting...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saveAndReconnect,
              child: const Text('Save & Connect'),
            ),
          ),
          const SizedBox(height: 32),

          // Auto Launch
          if (Platform.isMacOS || Platform.isWindows) ...[
            const Text(
              'General',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Launch at startup'),
              subtitle: const Text('Start VibeDesk when you log in'),
              value: _autoLaunch,
              onChanged: (value) async {
                if (value) {
                  await AutoLaunchService.enable();
                } else {
                  await AutoLaunchService.disable();
                }
                setState(() => _autoLaunch = AutoLaunchService.isEnabled);
              },
            ),
            Consumer(builder: (context, ref, _) {
              final enabled = ref.watch(clipboardSyncProvider);
              return SwitchListTile(
                title: const Text('Clipboard Sync'),
                subtitle: const Text('Sync clipboard text between local and remote'),
                value: enabled,
                onChanged: (value) {
                  ref.read(clipboardSyncProvider.notifier).setEnabled(value);
                },
              );
            }),
            const SizedBox(height: 32),
          ],

          // ICE Servers
          const Text(
            'ICE Servers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...config.servers.map((server) => ListTile(
                title: Text(server.urls),
                subtitle: server.username != null
                    ? Text('Auth: ${server.username}')
                    : null,
              )),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              _showAddServerDialog(context, ref);
            },
            child: const Text('Add ICE Server'),
          ),
        ],
      ),
    );
  }

  void _showAddServerDialog(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add ICE Server'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'URL (e.g. turn:turn.example.com:3478)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                final current = ref.read(iceConfigProvider);
                ref.read(iceConfigProvider.notifier).state = IceConfig(
                  servers: [...current.servers, IceServer(urls: url)],
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
