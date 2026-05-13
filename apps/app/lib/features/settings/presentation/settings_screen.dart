import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/ice_config.dart';

final iceConfigProvider = StateProvider<IceConfig>((ref) => const IceConfig());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(iceConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
