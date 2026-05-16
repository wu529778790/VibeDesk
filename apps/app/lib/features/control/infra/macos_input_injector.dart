import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../domain/input_event.dart';
import '../domain/input_injector.dart';

// CoreGraphics FFI bindings
final _coreGraphics = DynamicLibrary.open(
    '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics');

final _cgEventCreateMouseEvent = _coreGraphics.lookupFunction<
    Pointer Function(Pointer, Int32, Double, Double, Uint32),
    Pointer Function(Pointer, int, double, double, int)>(
    'CGEventCreateMouseEvent');

final _cgEventCreateKeyboardEvent = _coreGraphics.lookupFunction<
    Pointer Function(Pointer, Int16, Int8),
    Pointer Function(Pointer, int, int)>('CGEventCreateKeyboardEvent');

final _cgEventCreateScrollWheelEvent = _coreGraphics.lookupFunction<
    Pointer Function(Pointer, Uint32, Uint32, Int32, Int32),
    Pointer Function(Pointer, int, int, int, int)>(
    'CGEventCreateScrollWheelEvent');

final _cgEventPost = _coreGraphics.lookupFunction<
    Void Function(Uint32, Pointer),
    void Function(int, Pointer)>('CGEventPost');

final _cgEventSetFlags = _coreGraphics.lookupFunction<
    Void Function(Pointer, Uint64),
    void Function(Pointer, int)>('CGEventSetFlags');

final _axIsProcessTrusted = DynamicLibrary.open(
        '/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices')
    .lookupFunction<Int8 Function(), int Function()>('AXIsProcessTrusted');

// CGEventTypes
const _kCGEventMouseMoved = 5;
const _kCGEventLeftMouseDown = 1;
const _kCGEventLeftMouseUp = 2;
const _kCGEventRightMouseDown = 3;
const _kCGEventRightMouseUp = 4;
const _kCGEventOtherMouseDown = 25;
const _kCGEventOtherMouseUp = 26;
const _kCGEventTapLocationHID = 0;
const _kCGScrollEventUnitPixel = 1;

// CGEventFlags
const _kCGEventFlagMaskShift = 0x20000;
const _kCGEventFlagMaskControl = 0x40000;
const _kCGEventFlagMaskAlternate = 0x80000;
const _kCGEventFlagMaskCommand = 0x100000;

// macOS virtual key codes
const _keyMap = <String, int>{
  'A': 0x00, 'B': 0x0B, 'C': 0x08, 'D': 0x02, 'E': 0x0E, 'F': 0x03,
  'G': 0x05, 'H': 0x04, 'I': 0x22, 'J': 0x26, 'K': 0x28, 'L': 0x25,
  'M': 0x2E, 'N': 0x2D, 'O': 0x1F, 'P': 0x23, 'Q': 0x0C, 'R': 0x0F,
  'S': 0x01, 'T': 0x11, 'U': 0x20, 'V': 0x09, 'W': 0x0D, 'X': 0x07,
  'Y': 0x10, 'Z': 0x06,
  '1': 0x12, '2': 0x13, '3': 0x14, '4': 0x15, '5': 0x17,
  '6': 0x16, '7': 0x1A, '8': 0x1C, '9': 0x19, '0': 0x1D,
  'Enter': 0x24, 'Tab': 0x30, 'Escape': 0x35, 'Backspace': 0x33,
  'Delete': 0x75, 'Space': 0x31,
  'ArrowUp': 0x7E, 'ArrowDown': 0x7D, 'ArrowLeft': 0x7B, 'ArrowRight': 0x7C,
  'Home': 0x73, 'End': 0x77, 'PageUp': 0x74, 'PageDown': 0x79,
  'F1': 0x7A, 'F2': 0x78, 'F3': 0x63, 'F4': 0x76, 'F5': 0x60,
  'F6': 0x61, 'F7': 0x62, 'F8': 0x64, 'F9': 0x65, 'F10': 0x6B,
  'F11': 0x6D, 'F12': 0x6F,
  '-': 0x1B, '=': 0x18, '[': 0x21, ']': 0x1E, '\\': 0x2A,
  ';': 0x29, "'": 0x27, '`': 0x32, ',': 0x2B, '.': 0x2F, '/': 0x2C,
};

class MacOSInputInjector extends InputInjector {
  bool _accessibilityGranted = false;

  MacOSInputInjector() {
    _accessibilityGranted = _axIsProcessTrusted() != 0;
  }

  bool get isAccessibilityGranted => _accessibilityGranted;

  @override
  void setScreenSize(int width, int height) {
    // Not needed on macOS — CGEvent uses screen coordinates directly
  }

  @override
  Future<void> mouseMove(int x, int y) async {
    final event = _cgEventCreateMouseEvent(
        nullptr, _kCGEventMouseMoved, x.toDouble(), y.toDouble(), 0);
    _cgEventPost(_kCGEventTapLocationHID, event);
    calloc.free(event);
  }

  @override
  Future<void> mouseDown(int x, int y, MouseButton button) async {
    final (eventType, cgButton) = _mouseButtonParams(button, true);
    final event = _cgEventCreateMouseEvent(
        nullptr, eventType, x.toDouble(), y.toDouble(), cgButton);
    _cgEventPost(_kCGEventTapLocationHID, event);
    calloc.free(event);
  }

  @override
  Future<void> mouseUp(int x, int y, MouseButton button) async {
    final (eventType, cgButton) = _mouseButtonParams(button, false);
    final event = _cgEventCreateMouseEvent(
        nullptr, eventType, x.toDouble(), y.toDouble(), cgButton);
    _cgEventPost(_kCGEventTapLocationHID, event);
    calloc.free(event);
  }

  @override
  Future<void> mouseWheel(int x, int y, int deltaX, int deltaY) async {
    await mouseMove(x, y);
    if (deltaY != 0) {
      final event = _cgEventCreateScrollWheelEvent(
          nullptr, _kCGScrollEventUnitPixel, 1, (-deltaY * 3).clamp(-300, 300), 0);
      _cgEventPost(_kCGEventTapLocationHID, event);
      calloc.free(event);
    }
    if (deltaX != 0) {
      final event = _cgEventCreateScrollWheelEvent(
          nullptr, _kCGScrollEventUnitPixel, 1, 0, (-deltaX * 3).clamp(-300, 300));
      _cgEventPost(_kCGEventTapLocationHID, event);
      calloc.free(event);
    }
  }

  @override
  Future<void> keyDown(String key, List<ModifierKey> modifiers) async {
    final keyCode = _getKeyCode(key);
    final event = _cgEventCreateKeyboardEvent(nullptr, keyCode, 1);
    _setModifierFlags(event, modifiers);
    _cgEventPost(_kCGEventTapLocationHID, event);
    calloc.free(event);
  }

  @override
  Future<void> keyUp(String key, List<ModifierKey> modifiers) async {
    final keyCode = _getKeyCode(key);
    final event = _cgEventCreateKeyboardEvent(nullptr, keyCode, 0);
    _cgEventPost(_kCGEventTapLocationHID, event);
    calloc.free(event);
  }

  (int, int) _mouseButtonParams(MouseButton button, bool isDown) {
    return switch (button) {
      MouseButton.left => (
          isDown ? _kCGEventLeftMouseDown : _kCGEventLeftMouseUp,
          0
        ),
      MouseButton.right => (
          isDown ? _kCGEventRightMouseDown : _kCGEventRightMouseUp,
          1
        ),
      MouseButton.middle => (
          isDown ? _kCGEventOtherMouseDown : _kCGEventOtherMouseUp,
          2
        ),
    };
  }

  int _getKeyCode(String key) {
    if (key.length == 1) {
      final upper = key.toUpperCase();
      if (_keyMap.containsKey(upper)) return _keyMap[upper]!;
      if (_keyMap.containsKey(key)) return _keyMap[key]!;
    }
    return _keyMap[key] ?? 0x00;
  }

  void _setModifierFlags(Pointer event, List<ModifierKey> modifiers) {
    int flags = 0;
    for (final mod in modifiers) {
      flags |= switch (mod) {
        ModifierKey.shift => _kCGEventFlagMaskShift,
        ModifierKey.ctrl => _kCGEventFlagMaskControl,
        ModifierKey.alt => _kCGEventFlagMaskAlternate,
        ModifierKey.meta => _kCGEventFlagMaskCommand,
      };
    }
    if (flags != 0) _cgEventSetFlags(event, flags);
  }

  @override
  void dispose() {}
}
