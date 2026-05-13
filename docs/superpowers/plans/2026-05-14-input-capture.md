# Input Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement view/control mode switching in the remote control overlay, hiding the local cursor and capturing all keyboard input when in control mode.

**Architecture:** ControlOverlay manages an `_isControlling` state. A floating toolbar toggles this state. When controlling: local cursor is hidden via `MouseRegion`, keyboard events are intercepted and forwarded to the remote host, mouse events are sent via `onInputEvent`. Pressing Esc or losing window focus exits control mode.

**Tech Stack:** Flutter, `flutter_webrtc`, `SystemMouseCursors`, `FocusNode`, `HardwareKeyboard`

---

### Task 1: Add mode state and toolbar UI to ControlOverlay

**Files:**
- Modify: `apps/app/lib/features/control/presentation/control_overlay.dart`

- [ ] **Step 1: Add `_isControlling` state and toolbar**

Replace the full content of `control_overlay.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../domain/input_event.dart' as input;

class ControlOverlay extends StatefulWidget {
  final RTCVideoRenderer renderer;
  final void Function(input.InputEvent) onInputEvent;
  final void Function(Size widgetSize)? onSizeChanged;
  final VoidCallback? onConnectionLost;

  const ControlOverlay({
    super.key,
    required this.renderer,
    required this.onInputEvent,
    this.onSizeChanged,
    this.onConnectionLost,
  });

  @override
  State<ControlOverlay> createState() => _ControlOverlayState();
}

class _ControlOverlayState extends State<ControlOverlay> {
  final FocusNode _focusNode = FocusNode();
  Offset _lastPosition = Offset.zero;
  bool _isControlling = false;

  List<input.ModifierKey> _getActiveModifiers() {
    return [
      if (HardwareKeyboard.instance.isShiftPressed) input.ModifierKey.shift,
      if (HardwareKeyboard.instance.isControlPressed) input.ModifierKey.ctrl,
      if (HardwareKeyboard.instance.isAltPressed) input.ModifierKey.alt,
      if (HardwareKeyboard.instance.isMetaPressed) input.ModifierKey.meta,
    ];
  }

  void _toggleControl() {
    setState(() {
      _isControlling = !_isControlling;
    });
    if (_isControlling) {
      _focusNode.requestFocus();
    }
  }

  void _exitControl() {
    if (_isControlling) {
      setState(() {
        _isControlling = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _isControlling ? _handleKeyEvent : null,
      child: MouseRegion(
        cursor: _isControlling
            ? SystemMouseCursors.none
            : SystemMouseCursors.basic,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widgetSize =
                Size(constraints.maxWidth, constraints.maxHeight);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onSizeChanged?.call(widgetSize);
            });

            return Stack(
              children: [
                // Video feed — GestureDetector only active when controlling
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: _isControlling ? _onPanUpdate : null,
                  onPanDown: _isControlling ? _onPanDown : null,
                  onPanEnd: _isControlling ? _onPanEnd : null,
                  onSecondaryTapDown:
                      _isControlling ? _onSecondaryTapDown : null,
                  onSecondaryTapUp:
                      _isControlling ? _onSecondaryTapUp : null,
                  child: RTCVideoView(
                    widget.renderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  ),
                ),

                // Floating toolbar
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildToolbar(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isControlling ? 'Controlling' : 'View Only',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleControl,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _isControlling ? Colors.red.shade700 : Colors.blue.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isControlling ? 'Exit Control' : 'Control',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mouse event handlers (only called when _isControlling)
  // ---------------------------------------------------------------------------

  void _onPanUpdate(DragUpdateDetails details) {
    _lastPosition = details.localPosition;
    widget.onInputEvent(input.MouseMoveEvent(
      details.localPosition.dx,
      details.localPosition.dy,
    ));
  }

  void _onPanDown(DragDownDetails details) {
    _lastPosition = details.localPosition;
    widget.onInputEvent(input.MouseDownEvent(
      details.localPosition.dx,
      details.localPosition.dy,
      input.MouseButton.left,
    ));
  }

  void _onPanEnd(DragEndDetails details) {
    widget.onInputEvent(input.MouseUpEvent(
      _lastPosition.dx,
      _lastPosition.dy,
      input.MouseButton.left,
    ));
  }

  void _onSecondaryTapDown(TapDownDetails details) {
    widget.onInputEvent(input.MouseDownEvent(
      details.localPosition.dx,
      details.localPosition.dy,
      input.MouseButton.right,
    ));
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    widget.onInputEvent(input.MouseUpEvent(
      details.localPosition.dx,
      details.localPosition.dy,
      input.MouseButton.right,
    ));
  }

  // ---------------------------------------------------------------------------
  // Keyboard handling (only called when _isControlling)
  // ---------------------------------------------------------------------------

  void _handleKeyEvent(KeyEvent event) {
    // Esc exits control mode, never forwarded to remote
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _exitControl();
      return;
    }

    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final modifiers = _getActiveModifiers();
    final keyLabel = event.logicalKey.keyLabel;
    if (keyLabel.isEmpty) return;

    if (isDown) {
      widget.onInputEvent(input.KeyDownEvent(keyLabel, modifiers));
    } else if (event is KeyUpEvent) {
      widget.onInputEvent(input.KeyUpEvent(keyLabel, modifiers));
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Run analysis to verify no errors**

Run: `cd apps/app && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/features/control/presentation/control_overlay.dart
git commit -m "feat: add view/control mode switching with toolbar and cursor hiding"
```

---

### Task 2: Handle window focus loss — auto-exit control mode

**Files:**
- Modify: `apps/app/lib/features/control/presentation/control_overlay.dart`
- Modify: `apps/app/lib/features/room/presentation/room_screen.dart`

- [ ] **Step 1: Add focus listener to ControlOverlay**

In `control_overlay.dart`, update `initState` to listen for app focus changes:

```dart
@override
void initState() {
  super.initState();
  _focusNode.requestFocus();
  WidgetsBinding.instance.addObserver(_appLifecycleListener);
}
```

Add the observer and handler above `initState`:

```dart
final _appLifecycleListener = _AppLifecycleObserver();

// ... inside _ControlOverlayState ...

@override
void initState() {
  super.initState();
  _focusNode.requestFocus();
  WidgetsBinding.instance.addObserver(_appLifecycleListener);
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(_appLifecycleListener);
  _focusNode.dispose();
  super.dispose();
}
```

Add the lifecycle observer class at the bottom of the file (outside the State class):

```dart
class _AppLifecycleObserver with WidgetsBindingObserver {
  VoidCallback? onResumed;
  VoidCallback? onInactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResumed?.call();
      case AppLifecycleState.inactive:
        onInactive?.call();
      default:
        break;
    }
  }
}
```

Wire it up in `_ControlOverlayState.initState`:

```dart
@override
void initState() {
  super.initState();
  _appLifecycleListener.onInactive = _exitControl;
  _focusNode.requestFocus();
  WidgetsBinding.instance.addObserver(_appLifecycleListener);
}
```

- [ ] **Step 2: Run analysis**

Run: `cd apps/app && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/features/control/presentation/control_overlay.dart
git commit -m "feat: auto-exit control mode when app loses focus"
```

---

### Task 3: Pass connection state to ControlOverlay for edge case handling

**Files:**
- Modify: `apps/app/lib/features/room/presentation/room_screen.dart`

- [ ] **Step 1: Add `onConnectionLost` callback to ControlOverlay**

In `room_screen.dart`, where `ControlOverlay` is instantiated (inside `_buildConnectedBody`), add the `onConnectionLost` parameter:

Find the existing code:
```dart
return Container(
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
);
```

Replace with:
```dart
return Container(
  color: Colors.black,
  child: ControlOverlay(
    renderer: renderer,
    onInputEvent: _sendInputEvent,
    onSizeChanged: (size) {
      if (_widgetSize != size) {
        setState(() => _widgetSize = size);
      }
    },
    onConnectionLost: () {
      // Connection lost while controlling — handled by ICE state change
      // which already sets _connectionStatus and _errorMessage
    },
  ),
);
```

- [ ] **Step 2: Run analysis**

Run: `cd apps/app && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/features/room/presentation/room_screen.dart
git commit -m "feat: pass connection state callback to ControlOverlay"
```

---

### Task 4: Verify complete flow

- [ ] **Step 1: Run full analysis**

Run: `cd apps/app && flutter analyze`
Expected: No issues found

- [ ] **Step 2: Manual test checklist**

Verify on two machines (or same machine with host/client):
1. Open app, connect to signal server
2. Host shares screen, client joins room
3. Client sees remote screen — local cursor visible, "View Only" toolbar shown
4. Click "Control" button — local cursor hidden, toolbar shows "Controlling"
5. Move mouse — remote cursor moves correctly
6. Click on remote UI elements — clicks register on host
7. Type text — text appears on host
8. Press Esc — local cursor reappears, toolbar shows "View Only"
9. Click "Control" again — re-enters control mode
10. Click outside the video area (on app chrome) — control mode exits
11. Alt+Tab on host — works normally when not controlling

- [ ] **Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: input capture adjustments from manual testing"
```
