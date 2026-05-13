import 'dart:convert';

enum MouseButton { left, right, middle }

enum ModifierKey { shift, ctrl, alt, meta }

abstract class InputEvent {
  Map<String, dynamic> toJson();
  String serialize() => jsonEncode(toJson());
}

class MouseMoveEvent extends InputEvent {
  final double x;
  final double y;
  MouseMoveEvent(this.x, this.y);

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'mouse_move', 'x': x.round(), 'y': y.round()};
}

class MouseDownEvent extends InputEvent {
  final double x;
  final double y;
  final MouseButton button;
  MouseDownEvent(this.x, this.y, this.button);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'mouse_down',
        'x': x.round(),
        'y': y.round(),
        'button': button.name,
      };
}

class MouseUpEvent extends InputEvent {
  final double x;
  final double y;
  final MouseButton button;
  MouseUpEvent(this.x, this.y, this.button);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'mouse_up',
        'x': x.round(),
        'y': y.round(),
        'button': button.name,
      };
}

class KeyDownEvent extends InputEvent {
  final String key;
  final List<ModifierKey> modifiers;
  KeyDownEvent(this.key, this.modifiers);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'key_down',
        'key': key,
        'modifiers': modifiers.map((m) => m.name).toList(),
      };
}

class KeyUpEvent extends InputEvent {
  final String key;
  final List<ModifierKey> modifiers;
  KeyUpEvent(this.key, this.modifiers);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'key_up',
        'key': key,
        'modifiers': modifiers.map((m) => m.name).toList(),
      };
}
