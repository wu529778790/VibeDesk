# Seamless Remote Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the view/control mode toggle so that mouse+keyboard input is automatically forwarded when the cursor is inside the video area.

**Architecture:** Replace the `_isControlling` boolean state with `MouseRegion.onEnter/onExit` to manage keyboard focus. Remove the toolbar UI entirely. The `GestureDetector` always forwards mouse events.

**Tech Stack:** Flutter, Riverpod, flutter_webrtc

---

### Task 1: Rewrite ControlOverlay

**Files:**
- Modify: `apps/app/lib/features/control/presentation/control_overlay.dart`

- [ ] **Step 1: Rewrite control_overlay.dart**

Replace the entire file content with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../domain/input_event.dart' as input;

class ControlOverlay extends StatefulWidget {
  final RTCVideoRenderer renderer;
  final void Function(input.InputEvent) onInputEvent;
  final void Function(Size widgetSize)? onSizeChanged;

  const ControlOverlay({
    super.key,
    required this.renderer,
    required this.onInputEvent,
    this.onSizeChanged,
  });

  @override
  State<ControlOverlay> createState() => _ControlOverlayState();
}

class _ControlOverlayState extends State<ControlOverlay> {
  final FocusNode _focusNode = FocusNode();
  Offset _lastPosition = Offset.zero;

  List<input.ModifierKey> _getActiveModifiers() {
    return [
      if (HardwareKeyboard.instance.isShiftPressed) input.ModifierKey.shift,
      if (HardwareKeyboard.instance.isControlPressed) input.ModifierKey.ctrl,
      if (HardwareKeyboard.instance.isAltPressed) input.ModifierKey.alt,
      if (HardwareKeyboard.instance.isMetaPressed) input.ModifierKey.meta,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => _focusNode.requestFocus(),
        onExit: (_) => _focusNode.unfocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widgetSize =
                Size(constraints.maxWidth, constraints.maxHeight);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onSizeChanged?.call(widgetSize);
            });

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: _onPanUpdate,
              onPanDown: _onPanDown,
              onPanEnd: _onPanEnd,
              onSecondaryTapDown: _onSecondaryTapDown,
              onSecondaryTapUp: _onSecondaryTapUp,
              child: RTCVideoView(
                widget.renderer,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
            );
          },
        ),
      ),
    );
  }

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

  void _handleKeyEvent(KeyEvent event) {
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
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `cd apps/app && flutter analyze`
Expected: No errors related to control_overlay.dart

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/features/control/presentation/control_overlay.dart
git commit -m "feat: seamless control — mouse enter/exit drives input, remove toolbar"
```

---

### Task 2: Remove onConnectionLost from RoomScreen

**Files:**
- Modify: `apps/app/lib/features/room/presentation/room_screen.dart` (lines ~762-775)

- [ ] **Step 1: Remove onConnectionLost parameter**

Find the `ControlOverlay(` widget usage in `_buildConnectedBody()` and remove the `onConnectionLost` callback. Change from:

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

To:

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

- [ ] **Step 2: Run flutter analyze**

Run: `cd apps/app && flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/features/room/presentation/room_screen.dart
git commit -m "feat: remove onConnectionLost callback from RoomScreen"
```
