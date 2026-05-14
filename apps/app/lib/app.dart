import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'shared/models/user_role.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/connection_status.dart';
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
        builder: (context, state) => const _HomeScreen(),
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
// Home screen — auto-connects, shows role selection
// ---------------------------------------------------------------------------

class _HomeScreen extends ConsumerStatefulWidget {
  const _HomeScreen();

  @override
  ConsumerState<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<_HomeScreen> {
  bool _navigatedToSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final urlAsync = ref.read(signalServerProvider);
    if (urlAsync.isLoading) return;

    final url = urlAsync.valueOrNull;
    if (url == null || url.isEmpty) {
      _navigateToSettings();
      return;
    }

    final conn = ref.read(signalConnectionProvider.notifier);
    if (!conn.isConnected) {
      conn.connect(url);
    }
  }

  void _navigateToSettings() {
    if (_navigatedToSettings) return;
    _navigatedToSettings = true;
    context.push('/settings');
  }

  @override
  Widget build(BuildContext context) {
    final connStatus = ref.watch(signalConnectionProvider);
    final urlAsync = ref.watch(signalServerProvider);

    if (urlAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final url = urlAsync.valueOrNull;
    if (url == null || url.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToSettings());
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isConnected = connStatus.status == SignalConnectionStatus.connected;
    final isFailed = connStatus.status == SignalConnectionStatus.failed;

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monitor, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Remote Desktop Control',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ConnectionStatusBadge(
                status: _mapStatus(connStatus.status),
              ),
              if (isFailed) ...[
                const SizedBox(height: 8),
                Text(
                  connStatus.error ?? 'Connection failed',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _init,
                  child: const Text('Retry'),
                ),
              ],
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: isConnected
                    ? () => context.go('/room?role=host')
                    : null,
                icon: const Icon(Icons.screen_share),
                label: const Text('Share Screen (Host)'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: isConnected
                    ? () => context.go('/room?role=client')
                    : null,
                icon: const Icon(Icons.settings_remote),
                label: const Text('Remote Control (Client)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ConnectionStatus _mapStatus(SignalConnectionStatus status) {
    switch (status) {
      case SignalConnectionStatus.idle:
        return ConnectionStatus.idle;
      case SignalConnectionStatus.connecting:
        return ConnectionStatus.connecting;
      case SignalConnectionStatus.connected:
        return ConnectionStatus.connected;
      case SignalConnectionStatus.failed:
        return ConnectionStatus.failed;
    }
  }
}
