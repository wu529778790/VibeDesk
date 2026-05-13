import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'shared/theme/app_theme.dart';
import 'features/room/presentation/room_screen.dart';

enum UserRole { host, client }

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _HomeScreen(),
      ),
      GoRoute(
        path: '/host',
        builder: (context, state) =>
            const RoomScreen(role: UserRole.host),
      ),
      GoRoute(
        path: '/client',
        builder: (context, state) =>
            const RoomScreen(role: UserRole.client),
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

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VibeDesk')),
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
              onPressed: () => context.go('/host'),
              icon: const Icon(Icons.screen_share),
              label: const Text('Share Screen (Host)'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/client'),
              icon: const Icon(Icons.settings_remote),
              label: const Text('Remote Control (Client)'),
            ),
          ],
        ),
      ),
    );
  }
}
