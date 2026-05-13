import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../domain/input_event.dart' as input;

class ControlOverlay extends StatefulWidget {
  final RTCVideoRenderer renderer;
  final void Function(input.InputEvent) onInputEvent;

  const ControlOverlay({
    super.key,
    required this.renderer,
    required this.onInputEvent,
  });

  @override
  State<ControlOverlay> createState() => _ControlOverlayState();
}

class _ControlOverlayState extends State<ControlOverlay> {
  final FocusNode _focusNode = FocusNode();

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          widget.onInputEvent(input.MouseMoveEvent(
            details.localPosition.dx,
            details.localPosition.dy,
          ));
        },
        onPanDown: (details) {
          widget.onInputEvent(input.MouseDownEvent(
            details.localPosition.dx,
            details.localPosition.dy,
            input.MouseButton.left,
          ));
        },
        onPanEnd: (_) {
          widget.onInputEvent(input.MouseUpEvent(0, 0, input.MouseButton.left));
        },
        onSecondaryTapDown: (details) {
          widget.onInputEvent(input.MouseDownEvent(
            details.localPosition.dx,
            details.localPosition.dy,
            input.MouseButton.right,
          ));
        },
        onSecondaryTapUp: (details) {
          widget.onInputEvent(input.MouseUpEvent(
            details.localPosition.dx,
            details.localPosition.dy,
            input.MouseButton.right,
          ));
        },
        child: RTCVideoView(
          widget.renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        ),
      ),
    );
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
