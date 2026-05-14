# Seamless Remote Control Design

## Overview

Remove the manual view/control mode toggle. When the mouse is inside the remote desktop video area, all input (mouse + keyboard) is automatically forwarded to the remote host. The experience feels like operating your own computer — one cursor, no mode switching.

## User Experience

- **Local cursor always visible** — never hidden on the client side
- **Host cursor visible to host user** — not hidden, but excluded from screen capture video stream
- **No toolbar** — clean full-screen video
- **Mouse enters video area** → mouse and keyboard events forwarded to remote
- **Mouse leaves video area** → forwarding stops, keyboard released locally

## Design

### ControlOverlay Changes (`control_overlay.dart`)

**Remove:**
- `_isControlling` state
- `_toggleControl()` / `_exitControl()` methods
- `_buildToolbar()` widget and the floating toolbar UI
- `_AppLifecycleObserver` (auto-exit on focus loss no longer needed)

**Change:**
- `MouseRegion.cursor` → always `SystemMouseCursors.basic` (local cursor always visible)
- `MouseRegion.onEnter` → `_focusNode.requestFocus()` (capture keyboard)
- `MouseRegion.onExit` → `_focusNode.unfocus()` (release keyboard)
- `GestureDetector` → always active (remove `_isControlling` conditionals from `onPanUpdate`, `onPanDown`, `onPanEnd`, `onSecondaryTapDown`, `onSecondaryTapUp`)
- `KeyboardListener.onKeyEvent` → always forwards when focused (no `_isControlling` check)
- Esc key → forwarded to remote like any other key (no longer exits a mode)

**Keep unchanged:**
- `LayoutBuilder` for widget size tracking
- `RTCVideoView` with contain fit
- `onInputEvent` / `onSizeChanged` callbacks

### RoomScreen Changes (`room_screen.dart`)

**Remove:**
- `onConnectionLost` callback passed to `ControlOverlay`

**No other changes** — coordinate scaling, signaling, and WebRTC logic remain as-is.

### Screen Capture Cursor Exclusion (`screen_capturer.dart`)

Investigate whether `getDisplayMedia` on macOS/Windows supports excluding the cursor from the captured video stream. If the flutter_webrtc plugin exposes a `cursor` or `capturesCursor` option, set it to exclude. This is a best-effort improvement — if not supported by the plugin, it can be addressed in a future iteration via native code changes.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/control/presentation/control_overlay.dart` | Remove mode state, toolbar, cursor hiding; add MouseRegion enter/exit focus management |
| `lib/features/room/presentation/room_screen.dart` | Remove `onConnectionLost` callback |

## Out of Scope

- Platform-native cursor exclusion in screen capture (future iteration if plugin doesn't support it)
- Cursor shape customization
- Multiple monitor support
- Clipboard sync
