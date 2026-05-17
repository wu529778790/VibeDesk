import 'dart:io';
import '../domain/input_event.dart';
import '../domain/input_injector.dart';
import '../../../core/logger.dart';

class LinuxInputInjector extends InputInjector {
  bool _xdotoolAvailable = true;

  LinuxInputInjector() {
    _checkXdotool();
  }

  Future<void> _checkXdotool() async {
    try {
      final result = await Process.run('which', ['xdotool']);
      _xdotoolAvailable = result.exitCode == 0;
      if (!_xdotoolAvailable) {
        Logger.info('xdotool not found — Linux input injection disabled');
      }
    } catch (_) {
      _xdotoolAvailable = false;
    }
  }

  Future<void> _xdotool(List<String> args) async {
    if (!_xdotoolAvailable) return;
    try {
      await Process.run('xdotool', args);
    } catch (e) {
      Logger.error('xdotool error', e);
    }
  }

  @override
  void setScreenSize(int width, int height) {}

  @override
  Future<void> mouseMove(int x, int y) async {
    await _xdotool(['mousemove', '$x', '$y']);
  }

  @override
  Future<void> mouseDown(int x, int y, MouseButton button) async {
    final btn = _mouseButton(button);
    await _xdotool(['mousemove', '$x', '$y']);
    await _xdotool(['mousedown', btn]);
  }

  @override
  Future<void> mouseUp(int x, int y, MouseButton button) async {
    final btn = _mouseButton(button);
    await _xdotool(['mousemove', '$x', '$y']);
    await _xdotool(['mouseup', btn]);
  }

  @override
  Future<void> mouseWheel(int x, int y, int deltaX, int deltaY) async {
    await mouseMove(x, y);
    // xdotool: button 4 = scroll up, button 5 = scroll down
    // button 6 = scroll left, button 7 = scroll right
    if (deltaY != 0) {
      final clicks = (deltaY.abs()).clamp(1, 10);
      final btn = deltaY > 0 ? '5' : '4';
      for (var i = 0; i < clicks; i++) {
        await _xdotool(['click', btn]);
      }
    }
    if (deltaX != 0) {
      final clicks = (deltaX.abs()).clamp(1, 10);
      final btn = deltaX > 0 ? '7' : '6';
      for (var i = 0; i < clicks; i++) {
        await _xdotool(['click', btn]);
      }
    }
  }

  @override
  Future<void> keyDown(String key, List<ModifierKey> modifiers) async {
    final keysym = _toKeysym(key);
    final arg = _withModifiers(keysym, modifiers);
    await _xdotool(['keydown', arg]);
  }

  @override
  Future<void> keyUp(String key, List<ModifierKey> modifiers) async {
    final keysym = _toKeysym(key);
    final arg = _withModifiers(keysym, modifiers);
    await _xdotool(['keyup', arg]);
  }

  String _mouseButton(MouseButton button) => switch (button) {
        MouseButton.left => '1',
        MouseButton.middle => '2',
        MouseButton.right => '3',
      };

  static const _keyMap = <String, String>{
    'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e', 'F': 'f',
    'G': 'g', 'H': 'h', 'I': 'i', 'J': 'j', 'K': 'k', 'L': 'l',
    'M': 'm', 'N': 'n', 'O': 'o', 'P': 'p', 'Q': 'q', 'R': 'r',
    'S': 's', 'T': 't', 'U': 'u', 'V': 'v', 'W': 'w', 'X': 'x',
    'Y': 'y', 'Z': 'z',
    '1': '1', '2': '2', '3': '3', '4': '4', '5': '5',
    '6': '6', '7': '7', '8': '8', '9': '9', '0': '0',
    'Enter': 'Return', 'Tab': 'Tab', 'Escape': 'Escape',
    'Backspace': 'BackSpace', 'Delete': 'Delete', 'Space': 'space',
    'ArrowUp': 'Up', 'ArrowDown': 'Down',
    'ArrowLeft': 'Left', 'ArrowRight': 'Right',
    'Home': 'Home', 'End': 'End', 'PageUp': 'Page_Up', 'PageDown': 'Page_Down',
    'F1': 'F1', 'F2': 'F2', 'F3': 'F3', 'F4': 'F4', 'F5': 'F5',
    'F6': 'F6', 'F7': 'F7', 'F8': 'F8', 'F9': 'F9', 'F10': 'F10',
    'F11': 'F11', 'F12': 'F12',
    '-': 'minus', '=': 'equal', '[': 'bracketleft', ']': 'bracketright',
    '\\': 'backslash', ';': 'semicolon', "'": 'apostrophe',
    '`': 'grave', ',': 'comma', '.': 'period', '/': 'slash',
  };

  String _toKeysym(String key) {
    if (key.length == 1) {
      final lower = key.toLowerCase();
      if (_keyMap.containsKey(lower)) return _keyMap[lower]!;
      if (_keyMap.containsKey(key)) return _keyMap[key]!;
    }
    return _keyMap[key] ?? key.toLowerCase();
  }

  String _withModifiers(String keysym, List<ModifierKey> modifiers) {
    if (modifiers.isEmpty) return keysym;
    final mods = modifiers.map((m) => switch (m) {
          ModifierKey.shift => 'Shift_L',
          ModifierKey.ctrl => 'Control_L',
          ModifierKey.alt => 'Alt_L',
          ModifierKey.meta => 'Super_L',
        });
    return '${mods.join('+')}+$keysym';
  }

  @override
  void dispose() {}
}
