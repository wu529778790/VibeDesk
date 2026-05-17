import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../control/domain/input_event.dart' as input;
import '../../control/domain/input_injector.dart';
import '../../file_transfer/presentation/file_transfer_provider.dart';
import '../../../core/logger.dart';

typedef ScreenSizeCallback = void Function(int width, int height);
typedef ClipboardCallback = void Function(String text);

class DataChannelRouter {
  final InputInjector injector;
  final ScreenSizeCallback? onScreenSize;
  final ClipboardCallback? onClipboard;
  final FileTransferNotifier? fileTransferNotifier;

  DataChannelRouter({
    required this.injector,
    this.onScreenSize,
    this.onClipboard,
    this.fileTransferNotifier,
  });

  void route(RTCDataChannelMessage message) {
    if (message.isBinary) {
      _handleBinary(message.binary);
      return;
    }

    try {
      final json = jsonDecode(message.text) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'screen_size') {
        final w = (json['width'] as num?)?.toInt() ?? 1920;
        final h = (json['height'] as num?)?.toInt() ?? 1080;
        Logger.info('Received host screen size: ${w}x$h');
        onScreenSize?.call(w, h);
        return;
      }

      if (type == 'clipboard') {
        final text = json['text'] as String? ?? '';
        if (text.isNotEmpty) onClipboard?.call(text);
        return;
      }

      // File transfer control messages
      if (type != null && type.startsWith('file_transfer_')) {
        fileTransferNotifier?.handleTextMessage(json);
        return;
      }

      if (type == null) return;

      final x = (json['x'] as num?)?.toInt() ?? 0;
      final y = (json['y'] as num?)?.toInt() ?? 0;

      switch (type) {
        case 'mouse_move':
          injector.mouseMove(x, y);
        case 'mouse_down':
          injector.mouseDown(x, y, _parseMouseButton(json['button'] as String?));
        case 'mouse_up':
          injector.mouseUp(x, y, _parseMouseButton(json['button'] as String?));
        case 'mouse_wheel':
          final dx = (json['deltaX'] as num?)?.toInt() ?? 0;
          final dy = (json['deltaY'] as num?)?.toInt() ?? 0;
          injector.mouseWheel(x, y, dx, dy);
        case 'key_down':
          injector.keyDown(
            json['key'] as String? ?? '',
            _parseModifiers(json['modifiers']),
          );
        case 'key_up':
          injector.keyUp(
            json['key'] as String? ?? '',
            _parseModifiers(json['modifiers']),
          );
      }
    } catch (e) {
      Logger.error('Failed to handle data channel message', e);
    }
  }

  void _handleBinary(Uint8List data) {
    if (data.isEmpty) return;
    final prefix = data[0];
    if (prefix == 0x02) {
      fileTransferNotifier?.handleBinaryMessage(data);
    }
    // 0x01 = audio chunk (handled by audio channel, not here)
  }

  input.MouseButton _parseMouseButton(String? name) => switch (name) {
        'right' => input.MouseButton.right,
        'middle' => input.MouseButton.middle,
        _ => input.MouseButton.left,
      };

  List<input.ModifierKey> _parseModifiers(dynamic modifiers) {
    if (modifiers is! List) return [];
    return modifiers.map((m) => switch (m) {
          'shift' => input.ModifierKey.shift,
          'ctrl' => input.ModifierKey.ctrl,
          'alt' => input.ModifierKey.alt,
          'meta' => input.ModifierKey.meta,
          _ => input.ModifierKey.shift,
        }).toList();
  }
}
