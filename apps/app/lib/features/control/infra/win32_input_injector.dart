import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../domain/input_event.dart';
import '../domain/input_injector.dart';

class Win32InputInjector extends InputInjector {
  int _screenWidth = 1920;
  int _screenHeight = 1080;

  @override
  void setScreenSize(int width, int height) {
    _screenWidth = width;
    _screenHeight = height;
  }

  /// Convert pixel coordinates to Windows absolute coordinates (0-65535)
  int _normalizeX(double x) =>
      ((x / _screenWidth) * 65535).round().clamp(0, 65535);

  int _normalizeY(double y) =>
      ((y / _screenHeight) * 65535).round().clamp(0, 65535);

  VIRTUAL_KEY _getVirtualKeyCode(String key) {
    const keyMap = <String, VIRTUAL_KEY>{
      'Enter': VIRTUAL_KEY(0x0D),
      'Tab': VIRTUAL_KEY(0x09),
      'Escape': VIRTUAL_KEY(0x1B),
      'Backspace': VIRTUAL_KEY(0x08),
      'Delete': VIRTUAL_KEY(0x2E),
      'Space': VIRTUAL_KEY(0x20),
      'ArrowUp': VIRTUAL_KEY(0x26),
      'ArrowDown': VIRTUAL_KEY(0x28),
      'ArrowLeft': VIRTUAL_KEY(0x25),
      'ArrowRight': VIRTUAL_KEY(0x27),
      'Home': VIRTUAL_KEY(0x24),
      'End': VIRTUAL_KEY(0x23),
      'PageUp': VIRTUAL_KEY(0x21),
      'PagePageDown': VIRTUAL_KEY(0x22),
      'F1': VIRTUAL_KEY(0x70),
      'F2': VIRTUAL_KEY(0x71),
      'F3': VIRTUAL_KEY(0x72),
      'F4': VIRTUAL_KEY(0x73),
      'F5': VIRTUAL_KEY(0x74),
      'F6': VIRTUAL_KEY(0x75),
      'F7': VIRTUAL_KEY(0x76),
      'F8': VIRTUAL_KEY(0x77),
      'F9': VIRTUAL_KEY(0x78),
      'F10': VIRTUAL_KEY(0x79),
      'F11': VIRTUAL_KEY(0x7A),
      'F12': VIRTUAL_KEY(0x7B),
    };
    return keyMap[key] ?? VIRTUAL_KEY(key.codeUnitAt(0));
  }

  @override
  Future<void> mouseMove(int x, int y) async {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.Anonymous.mi.dx = _normalizeX(x.toDouble());
      input.ref.Anonymous.mi.dy = _normalizeY(y.toDouble());
      input.ref.Anonymous.mi.dwFlags =
          MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  @override
  Future<void> mouseDown(int x, int y, MouseButton button) async {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.Anonymous.mi.dx = _normalizeX(x.toDouble());
      input.ref.Anonymous.mi.dy = _normalizeY(y.toDouble());

      switch (button) {
        case MouseButton.left:
          input.ref.Anonymous.mi.dwFlags = MOUSEEVENTF_MOVE |
              MOUSEEVENTF_ABSOLUTE |
              MOUSEEVENTF_LEFTDOWN;
        case MouseButton.right:
          input.ref.Anonymous.mi.dwFlags = MOUSEEVENTF_MOVE |
              MOUSEEVENTF_ABSOLUTE |
              MOUSEEVENTF_RIGHTDOWN;
        case MouseButton.middle:
          input.ref.Anonymous.mi.dwFlags = MOUSEEVENTF_MOVE |
              MOUSEEVENTF_ABSOLUTE |
              MOUSEEVENTF_MIDDLEDOWN;
      }
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  @override
  Future<void> mouseUp(int x, int y, MouseButton button) async {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.Anonymous.mi.dx = _normalizeX(x.toDouble());
      input.ref.Anonymous.mi.dy = _normalizeY(y.toDouble());

      switch (button) {
        case MouseButton.left:
          input.ref.Anonymous.mi.dwFlags = MOUSEEVENTF_MOVE |
              MOUSEEVENTF_ABSOLUTE |
              MOUSEEVENTF_LEFTUP;
        case MouseButton.right:
          input.ref.Anonymous.mi.dwFlags = MOUSEEVENTF_MOVE |
              MOUSEEVENTF_ABSOLUTE |
              MOUSEEVENTF_RIGHTUP;
        case MouseButton.middle:
          input.ref.Anonymous.mi.dwFlags = MOUSEEVENTF_MOVE |
              MOUSEEVENTF_ABSOLUTE |
              MOUSEEVENTF_MIDDLEUP;
      }
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  @override
  Future<void> keyDown(String key, List<ModifierKey> modifiers) async {
    final vk = _getVirtualKeyCode(key);
    const flags = KEYBD_EVENT_FLAGS(0);

    for (final mod in modifiers) {
      _sendKeyPress(_getModifierVk(mod), flags);
    }
    _sendKeyPress(vk, flags);
  }

  @override
  Future<void> keyUp(String key, List<ModifierKey> modifiers) async {
    final vk = _getVirtualKeyCode(key);
    const flags = KEYEVENTF_KEYUP;

    _sendKeyPress(vk, flags);
    for (final mod in modifiers) {
      _sendKeyPress(_getModifierVk(mod), flags);
    }
  }

  void _sendKeyPress(VIRTUAL_KEY vk, KEYBD_EVENT_FLAGS flags) {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_KEYBOARD;
      input.ref.Anonymous.ki.wVk = vk;
      input.ref.Anonymous.ki.dwFlags = flags;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  VIRTUAL_KEY _getModifierVk(ModifierKey mod) {
    switch (mod) {
      case ModifierKey.shift:
        return VIRTUAL_KEY(0x10);
      case ModifierKey.ctrl:
        return VIRTUAL_KEY(0x11);
      case ModifierKey.alt:
        return VIRTUAL_KEY(0x12);
      case ModifierKey.meta:
        return VIRTUAL_KEY(0x5B);
    }
  }

  @override
  void dispose() {}
}
