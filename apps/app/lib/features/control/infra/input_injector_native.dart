import 'dart:io';
import '../domain/input_injector.dart';
import '../domain/input_event.dart';
import 'linux_input_injector.dart';
import 'macos_input_injector.dart';
import 'win32_input_injector.dart';

InputInjector createPlatformInputInjector() {
  if (Platform.isWindows) {
    return Win32InputInjector();
  }
  if (Platform.isMacOS) {
    return MacOSInputInjector();
  }
  if (Platform.isLinux) {
    return LinuxInputInjector();
  }
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
