# UI Overhaul Design

## Overview

Restructure the app flow: auto-connect on startup, hide server details, role selection as home screen, remote desktop in fullscreen mode (no AppBar).

## User Experience

### App Flow

1. **Launch** → check if server URL configured
2. **Not configured** (first launch) → redirect to Settings page
3. **Configured** → auto-connect in background, show role selection immediately
4. **Role Selection** → two buttons: Share Screen (Host) / Remote Control (Client)
5. **Host** → auto-create room, show room code, wait for client
6. **Client** → enter room code, join room
7. **Connected (client)** → fullscreen remote desktop, no AppBar, press Esc to exit

### Key Principles

- Server URL never shown on main flow — only in Settings
- Auto-connect is invisible — no "Connecting to server..." screen
- Role selection is the home screen after first-time setup
- Remote desktop goes fullscreen (same window), no AppBar wasting space
- Press Esc to exit fullscreen and return to home

## Design

### Route Changes (`app.dart`)

**Remove:**
- `_SetupScreen` — the server URL input page
- `_RootScreen` connecting/disconnecting states — no loading screens

**Replace with:**
- `_HomeScreen` — role selection with auto-connect, connection status as small badge

**Routes stay the same:**
- `/` → `_HomeScreen`
- `/room?role=host|client` → `RoomScreen`
- `/settings` → `SettingsScreen`

### Home Screen (`_HomeScreen`)

- Auto-connects on init using saved server URL
- If no URL → navigates to Settings
- Small `ConnectionStatusBadge` below subtitle
- Buttons disabled when not connected
- Error text + retry button if connection fails

### RoomScreen Changes (`room_screen.dart`)

**Client connected state:**
- Remove AppBar entirely when showing remote stream
- Fullscreen black background with ControlOverlay
- No back button, no status bar
- Esc key exits fullscreen and returns to home (`context.go('/')`)

**Host connected state:**
- Keep AppBar with back button and status badge (host needs to see room code)

## Files to Modify

| File | Change |
|--------|--------|
| `apps/app/lib/app.dart` | Replace `_RootScreen`/`_SetupScreen`/`_MainScreen` with `_HomeScreen` |

| File | Change |
|--------|--------|
| `apps/app/lib/features/room/presentation/room_screen.dart` | Client: remove AppBar when connected, add Esc to exit |

## Out of Scope

- System tray integration
- Multiple remote sessions
- Clipboard sync
- desktop_multi_window (deferred — fullscreen mode sufficient)
