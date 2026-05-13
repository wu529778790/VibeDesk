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
