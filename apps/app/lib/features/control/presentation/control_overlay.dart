import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

            return Listener(
              onPointerSignal: _onPointerSignal,
              child: GestureDetector(
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

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      widget.onInputEvent(input.MouseWheelEvent(
        event.localPosition.dx,
        event.localPosition.dy,
        event.scrollDelta.dx.round(),
        event.scrollDelta.dy.round(),
      ));
    }
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
