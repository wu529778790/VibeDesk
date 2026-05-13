# Remote Control Input Capture Design

## Overview

Design the input capture logic for VibeDesk's remote control feature. When a client controls a remote host, the local cursor and keyboard must be properly managed to avoid dual-cursor issues and ensure all input reaches the remote machine.

## Goals

- Hide local cursor when in control mode, show only the remote cursor (from video stream)
- Capture all keyboard events and forward to remote machine
- Provide clear mode switching via toolbar and Esc key
- Handle edge cases (connection loss, window focus loss)

## Mode Definition

Two mutually exclusive modes:

| | View Mode | Control Mode |
|---|---|---|
| Local cursor | Visible | Hidden |
| Mouse events | Not sent | Sent to remote |
| Keyboard events | Not intercepted | All intercepted and sent to remote |
| Remote screen | View only | Interactive |

Switching: toolbar button click, or press Esc to exit control mode.

## ControlOverlay Internal Structure

```
ControlOverlay
├── State
│   └── _isControlling: bool (default false)
│
├── Toolbar (floating at top of video)
│   ├── "View" button — highlighted when in view mode
│   ├── "Control" button — highlighted when in control mode
│   └── Status text: "View Only" / "Controlling"
│
├── Mouse handling
│   ├── MouseRegion: cursor = _isControlling ? none : basic
│   └── GestureDetector (only active when _isControlling):
│       ├── onPanUpdate → mouse move
│       ├── onPanDown → mouse down
│       ├── onPanEnd → mouse up
│       ├── onSecondaryTapDown → right click down
│       └── onSecondaryTapUp → right click up
│
├── Keyboard handling (only intercepted when _isControlling)
│   ├── KeyDownEvent → send to remote
│   ├── KeyRepeatEvent → send to remote
│   ├── KeyUpEvent → send to remote
│   ├── Esc → exit control mode (not forwarded)
│   └── Other modifier combos → forwarded normally
│
└── RTCVideoView (always renders remote screen)
```

## Data Flow

```
User Action             ControlOverlay           RoomScreen           Remote Host
    │                        │                       │                    │
    ├─ Click "Control" ────→ │ isControlling=true    │                    │
    │                        │ Hide local cursor     │                    │
    │                        │ Activate kbd capture  │                    │
    │                        │                       │                    │
    ├─ Move mouse ─────────→ │ onInputEvent(Mouse) ─→ │ scaleCoords ────→ │ SendInput
    ├─ Click mouse ────────→ │ onInputEvent(Mouse) ─→ │ scaleCoords ────→ │ SendInput
    ├─ Press key ──────────→ │ onInputEvent(Key) ───→ │ Forward ────────→ │ SendInput
    │                        │                       │                    │
    ├─ Press Esc ──────────→ │ isControlling=false   │                    │
    │                        │ Restore local cursor  │                    │
    │                        │ Release kbd capture   │                    │
```

## Edge Cases

| Scenario | Handling |
|---|---|
| Connection drops while in control mode | Auto-exit control mode, show error |
| Video stream interrupted | Keep current mode, show loading state |
| Window loses focus | Auto-exit control mode (prevent background input) |
| Esc key intercepted by remote host | Local handles Esc first, does not forward |
| Modifier key combos (Ctrl+C etc.) | Forward all modifier keys normally |
| Mouse exits window boundary | Clamp to window edge in control mode |

## Files to Modify

- `lib/features/control/presentation/control_overlay.dart` — main changes
- `lib/features/room/presentation/room_screen.dart` — minor: pass connection state for edge case handling

## Out of Scope

- Cursor shape customization
- Multiple monitor selection
- Clipboard synchronization (planned for v0.3.x)
- File drag and drop
