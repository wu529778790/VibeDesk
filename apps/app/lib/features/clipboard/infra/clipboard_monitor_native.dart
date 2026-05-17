import 'dart:async';
import 'dart:io';

import '../domain/clipboard_sync.dart';
import '../../../core/logger.dart';

ClipboardMonitor createPlatformClipboardMonitor() {
  if (Platform.isMacOS) return _MacOSClipboardMonitor();
  if (Platform.isWindows) return _WindowsClipboardMonitor();
  if (Platform.isLinux) return _LinuxClipboardMonitor();
  return _NoOpClipboardMonitor();
}

class _MacOSClipboardMonitor extends ClipboardMonitor {
  final _controller = StreamController<String>.broadcast();
  Timer? _timer;
  String? _lastContent;
  bool _disposed = false;

  _MacOSClipboardMonitor() {
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_disposed) return;
      try {
        final result = await Process.run('pbpaste', []);
        if (result.exitCode == 0) {
          final text = result.stdout as String;
          if (text != _lastContent) {
            _lastContent = text;
            _controller.add(text);
          }
        }
      } catch (e) {
        Logger.error('Clipboard read failed (macOS)', e);
      }
    });
  }

  @override
  Stream<String> get onClipboardChanged => _controller.stream;

  @override
  Future<void> setClipboard(String text) async {
    try {
      final process = await Process.start('pbcopy', []);
      process.stdin.write(text);
      await process.stdin.close();
      await process.exitCode;
      _lastContent = text;
    } catch (e) {
      Logger.error('Clipboard write failed (macOS)', e);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.close();
  }
}

class _WindowsClipboardMonitor extends ClipboardMonitor {
  final _controller = StreamController<String>.broadcast();
  Timer? _timer;
  String? _lastContent;
  bool _disposed = false;

  _WindowsClipboardMonitor() {
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_disposed) return;
      try {
        final result = await Process.run(
          'powershell',
          ['-command', '-NoProfile', 'Get-Clipboard'],
        );
        if (result.exitCode == 0) {
          final text = (result.stdout as String).trimRight();
          if (text != _lastContent) {
            _lastContent = text;
            _controller.add(text);
          }
        }
      } catch (e) {
        Logger.error('Clipboard read failed (Windows)', e);
      }
    });
  }

  @override
  Stream<String> get onClipboardChanged => _controller.stream;

  @override
  Future<void> setClipboard(String text) async {
    try {
      final escaped = text
          .replaceAll("'", "''")
          .replaceAll('\n', '`n')
          .replaceAll('\r', '`r');
      await Process.run(
        'powershell',
        ['-command', '-NoProfile', "Set-Clipboard -Value '$escaped'"],
      );
      _lastContent = text;
    } catch (e) {
      Logger.error('Clipboard write failed (Windows)', e);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.close();
  }
}

class _LinuxClipboardMonitor extends ClipboardMonitor {
  final _controller = StreamController<String>.broadcast();
  Timer? _timer;
  String? _lastContent;
  bool _disposed = false;

  _LinuxClipboardMonitor() {
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_disposed) return;
      try {
        final result = await Process.run(
          'xclip',
          ['-selection', 'clipboard', '-o'],
        );
        if (result.exitCode == 0) {
          final text = result.stdout as String;
          if (text != _lastContent) {
            _lastContent = text;
            _controller.add(text);
          }
        }
      } catch (e) {
        Logger.error('Clipboard read failed (Linux)', e);
      }
    });
  }

  @override
  Stream<String> get onClipboardChanged => _controller.stream;

  @override
  Future<void> setClipboard(String text) async {
    try {
      final process = await Process.start(
        'xclip',
        ['-selection', 'clipboard'],
      );
      process.stdin.write(text);
      await process.stdin.close();
      await process.exitCode;
      _lastContent = text;
    } catch (e) {
      Logger.error('Clipboard write failed (Linux)', e);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.close();
  }
}

class _NoOpClipboardMonitor extends ClipboardMonitor {
  @override
  Stream<String> get onClipboardChanged => const Stream.empty();

  @override
  Future<void> setClipboard(String text) async {}

  @override
  void dispose() {}
}
