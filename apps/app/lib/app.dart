import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'shared/models/user_role.dart';
import 'shared/theme/app_theme.dart';
import 'core/signaling/signal_server_provider.dart';
import 'features/room/presentation/room_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _RootScreen(),
      ),
      GoRoute(
        path: '/room',
        builder: (context, state) {
          final roleStr = state.uri.queryParameters['role'] ?? 'host';
          final role = roleStr == 'client' ? UserRole.client : UserRole.host;
          return RoomScreen(role: role);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

class VibeDeskApp extends ConsumerWidget {
  const VibeDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'VibeDesk',
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}

// ---------------------------------------------------------------------------
// Root screen — auto-connects and routes to main or setup
// ---------------------------------------------------------------------------

class _RootScreen extends ConsumerStatefulWidget {
  const _RootScreen();

  @override
  ConsumerState<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<_RootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
  }

  void _autoConnect() {
    final conn = ref.read(signalConnectionProvider.notifier);
    if (conn.isConnected) return;

    final urlAsync = ref.read(signalServerProvider);
    final url = urlAsync.valueOrNull;
    if (url != null && url.isNotEmpty) {
      conn.connect(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connStatus = ref.watch(signalConnectionProvider);

    // Still loading server URL from disk
    final urlAsync = ref.watch(signalServerProvider);
    if (urlAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Connected → show role selection
    if (connStatus.status == SignalConnectionStatus.connected) {
      return const _MainScreen();
    }

    // Connecting
    if (connStatus.status == SignalConnectionStatus.connecting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Connecting to server...'),
            ],
          ),
        ),
      );
    }

    // Disconnected / failed → show setup
    return _SetupScreen(
      error: connStatus.error,
      onRetry: _autoConnect,
    );
  }
}

// ---------------------------------------------------------------------------
// Setup screen — enter server URL and connect
// ---------------------------------------------------------------------------

class _SetupScreen extends ConsumerStatefulWidget {
  final String? error;
  final VoidCallback onRetry;

  const _SetupScreen({this.error, required this.onRetry});

  @override
  ConsumerState<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<_SetupScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final url = ref.read(signalServerProvider).valueOrNull ?? '';
    _controller = TextEditingController(text: url);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.monitor, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'VibeDesk',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Remote Desktop Control',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Signal Server URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns),
                  ),
                ),
                if (widget.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final url = _controller.text.trim();
                    if (url.isEmpty) return;
                    ref.read(signalServerProvider.notifier).setUrl(url);
                    ref.read(signalConnectionProvider.notifier).connect(url);
                  },
                  child: const Text('Connect'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main screen — role selection after connected
// ---------------------------------------------------------------------------

class _MainScreen extends ConsumerWidget {
  const _MainScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VibeDesk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monitor, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Remote Desktop Control',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () => context.go('/room?role=host'),
              icon: const Icon(Icons.screen_share),
              label: const Text('Share Screen (Host)'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/room?role=client'),
              icon: const Icon(Icons.settings_remote),
              label: const Text('Remote Control (Client)'),
            ),
          ],
        ),
      ),
    );
  }
}
