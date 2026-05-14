# UI Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure app — auto-connect on startup, no server URL page, role selection as home, client remote desktop goes fullscreen without AppBar.

**Architecture:** Replace `_RootScreen`/`_SetupScreen`/`_MainScreen` with a single `_HomeScreen` that auto-connects and shows role selection. Client RoomScreen removes AppBar when remote stream is active. Esc exits fullscreen.

**Tech Stack:** Flutter, Riverpod, go_router

---

### Task 1: Rewrite app.dart — HomeScreen with auto-connect

**Files:**
- Modify: `apps/app/lib/app.dart`

- [ ] **Step 1: Rewrite app.dart**

Replace entire file with:

```dart
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
```

- [ ] **Step 2: Run flutter analyze**

Run: `cd apps/app && flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/app.dart
git commit -m "feat: replace RootScreen/SetupScreen with auto-connect HomeScreen"
```

---

### Task 2: Update RoomScreen — client fullscreen, no AppBar

**Files:**
- Modify: `apps/app/lib/features/room/presentation/room_screen.dart`

- [ ] **Step 1: Modify build() method**

Find the `build()` method (around line 545):

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }
```

Replace with:

```dart
  @override
  Widget build(BuildContext context) {
    // Client with remote stream: fullscreen, no AppBar
    if (!_isHost && _hasRemoteStream) {
      return _buildClientFullscreen();
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }
```

- [ ] **Step 2: Add _buildClientFullscreen() method**

Add this new method to `_RoomScreenState`:

```dart
  Widget _buildClientFullscreen() {
    final renderer = ref.watch(screenProvider);
    if (renderer == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Intercept Esc key to exit fullscreen
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _disconnectAndGoBack();
        }
      },
      child: Container(
        color: Colors.black,
        child: ControlOverlay(
          renderer: renderer,
          onInputEvent: _sendInputEvent,
          onSizeChanged: (size) {
            if (_widgetSize != size) {
              setState(() => _widgetSize = size);
            }
          },
        ),
      ),
    );
  }
```

Note: Need to add `import 'package:flutter/services.dart';` at the top if not already present.

- [ ] **Step 3: Add import for LogicalKeyboardKey**

At the top of `room_screen.dart`, add if not present:

```dart
import 'package:flutter/services.dart';
```

- [ ] **Step 4: Update _buildConnectedBody — simplify client connected section**

Find the client connected block that shows `ControlOverlay` (lines ~746-772). Replace the entire `if (!_isHost && _hasRemoteStream)` block:

```dart
    // Client: showing remote stream — handled by build() fullscreen
    if (!_isHost && _hasRemoteStream) {
      return const SizedBox.shrink();
    }
```

This state is now handled by `_buildClientFullscreen()` in `build()`, so the `_buildConnectedBody` path won't render it.

- [ ] **Step 5: Run flutter analyze**

Run: `cd apps/app && flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add apps/app/lib/features/room/presentation/room_screen.dart
git commit -m "feat: client remote desktop fullscreen without AppBar, Esc to exit"
```

---

### Task 3: Clean up unused files

**Files:**
- Delete: `apps/app/lib/features/remote/` (if created from earlier plan iteration)
- Delete: `apps/app/lib/features/screen/presentation/screen_view.dart` (if unused)

- [ ] **Step 1: Check for unused files**

Run: `grep -r "screen_view" apps/app/lib/ || echo "not imported"`
Expected: No imports found → safe to delete

- [ ] **Step 2: Delete unused file if confirmed**

```bash
rm apps/app/lib/features/screen/presentation/screen_view.dart
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove unused screen_view widget"
```

---

### Task 4: Build and smoke test

- [ ] **Step 1: Build macOS**

Run: `cd apps/app && flutter build macos --debug`
Expected: Build succeeded

- [ ] **Step 2: Run and verify**

Run: `cd apps/app && flutter run -d macos`

Verify:
1. App launches → auto-connects → shows role selection (no server URL page)
2. Settings icon → navigates to settings
3. "Share Screen (Host)" → shows room code with AppBar
4. "Remote Control (Client)" → room code input
5. Client connects to host → fullscreen remote desktop, no AppBar
6. Press Esc → exits fullscreen, returns to home

- [ ] **Step 3: Commit fixes if needed**

```bash
git add -A
git commit -m "fix: address smoke test issues"
```
