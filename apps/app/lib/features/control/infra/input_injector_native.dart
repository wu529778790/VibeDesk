import 'dart:io';
import '../domain/input_injector.dart';
import '../domain/input_event.dart';
import 'win32_input_injector.dart';

InputInjector createPlatformInputInjector() {
  if (Platform.isWindows) {
    return Win32InputInjector();
  }
  // macOS/Linux: input injection not yet supported, return no-op stub
  return _NoOpInputInjector();
}

class _NoOpInputInjector extends InputInjector {
  @override
  Future<void> mouseMove(int x, int y) async {}
  @override
  Future<void> mouseDown(int x, int y, MouseButton button) async {}
  @override
  Future<void> mouseUp(int x, int y, MouseButton button) async {}
  @override
  Future<void> mouseWheel(int x, int y, int deltaX, int deltaY) async {}
  @override
  Future<void> keyDown(String key, List<ModifierKey> modifiers) async {}
  @override
  Future<void> keyUp(String key, List<ModifierKey> modifiers) async {}
  @override
  void dispose() {}
}
