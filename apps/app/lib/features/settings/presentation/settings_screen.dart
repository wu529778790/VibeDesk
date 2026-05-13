import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/signaling/signal_server_provider.dart';
import '../domain/ice_config.dart';

final iceConfigProvider = StateProvider<IceConfig>((ref) => const IceConfig());

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _serverController;

  @override
  void initState() {
    super.initState();
    final url = ref.read(signalServerProvider).valueOrNull ?? '';
    _serverController = TextEditingController(text: url);
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(iceConfigProvider);

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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final url = _serverController.text.trim();
                if (url.isNotEmpty) {
                  ref.read(signalServerProvider.notifier).setUrl(url);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Server URL saved')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ),
          const SizedBox(height: 32),

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
