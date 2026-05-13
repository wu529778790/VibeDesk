# Input Injection Design

## Problem

Client can see host screen via WebRTC video stream, but cannot click or control it. The host side has zero implementation for receiving input events from the DataChannel and injecting them into the OS.

## Architecture

```
Client                          Host
┌──────────────┐               ┌──────────────────────┐
│ ControlOverlay│               │ DataChannel listener  │
│ (gestures)    │               │ (receive JSON)        │
│      ↓        │  DataChannel  │      ↓                │
│ InputEvent    │──────→        │ InputInjector         │
│ (serialize)   │               │  ├─ Win32InputInjector │
└──────────────┘               │  └─ MacOSInputInjector │
                               │      ↓                │
                               │ OS: SendInput/CGEvent │
                               └──────────────────────┘
```

## Components

### 1. InputInjector Interface

```dart
abstract class InputInjector {
  Future<void> mouseMove(int x, int y);
  Future<void> mouseDown(int x, int y, MouseButton button);
  Future<void> mouseUp(int x, int y, MouseButton button);
  Future<void> keyDown(String key, List<String> modifiers);
  Future<void> keyUp(String key, List<String> modifiers);
  void dispose();
}
```

### 2. Windows Implementation (`Win32InputInjector`)

- Package: `win32` (v6.2.0) — FFI bindings to Windows API
- Uses `SendInput` with `INPUT_MOUSE` and `INPUT_KEYBOARD` structures
- Maps MouseButton to `MOUSEEVENTF_LEFTDOWN/UP`, `RIGHTDOWN/UP`
- Maps Flutter key labels to Windows virtual key codes

### 3. macOS Implementation (`MacOSInputInjector`)

- Platform Channel: `com.vibedesk/input`
- Native Swift code using `CGEvent` API
- `CGEvent.mouseEvent` for mouse moves/clicks
- `CGEvent.keyboardEvent` for key events
- Requires Accessibility permissions (System Preferences > Privacy > Accessibility)

### 4. Host-side DataChannel Handler

In `room_screen.dart`, host's `onDataChannel` callback:
1. Store dataChannel reference
2. Register `onMessage` listener
3. Deserialize JSON to InputEvent
4. Scale coordinates: `hostX = clientX * screenW / widgetW`
5. Call InputInjector method

### 5. Coordinate Scaling

Client sends raw Flutter logical pixels. Host maps to screen resolution:
- Host sends screen dimensions to client at connection start
- Client sends widget dimensions with each event (or once at start)
- Host computes: `hostX = clientX * screenWidth / clientWidgetWidth`

Simpler approach: client sends normalized coordinates (0.0-1.0), host multiplies by screen size.

### 6. ControlOverlay Bug Fix

`onPanEnd` currently sends `(0, 0)`. Fix: cache last position from `onPanUpdate`, use it in `onPanEnd`.

## Files to Create/Modify

### New Files
- `lib/features/control/domain/input_injector.dart` — Interface
- `lib/features/control/infra/win32_input_injector.dart` — Windows impl
- `lib/features/control/infra/macos_input_injector.dart` — macOS impl (Dart side)
- `lib/features/control/infra/input_injector_factory.dart` — Platform dispatch
- `macos/Runner/InputPlugin.swift` — macOS native code

### Modified Files
- `lib/features/room/presentation/room_screen.dart` — Host DataChannel handler + coordinate scaling
- `lib/features/control/presentation/control_overlay.dart` — Fix onPanEnd bug + send widget size
- `apps/app/pubspec.yaml` — Add `win32` dependency
- `macos/Runner/Info.plist` — Accessibility permission description

## Testing

- Unit tests for InputInjector interface and coordinate scaling
- Manual test: Mac client controls Windows host mouse/keyboard
- Manual test: Windows client controls Mac host mouse/keyboard
