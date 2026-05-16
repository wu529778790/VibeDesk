import 'input_event.dart';

abstract class InputInjector {
  void setScreenSize(int width, int height) {}
  Future<void> mouseMove(int x, int y);
  Future<void> mouseDown(int x, int y, MouseButton button);
  Future<void> mouseUp(int x, int y, MouseButton button);
  Future<void> mouseWheel(int x, int y, int deltaX, int deltaY);
  Future<void> keyDown(String key, List<ModifierKey> modifiers);
  Future<void> keyUp(String key, List<ModifierKey> modifiers);
  void dispose();
}
