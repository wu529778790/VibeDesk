import '../domain/clipboard_sync.dart';

ClipboardMonitor createPlatformClipboardMonitor() => _NoOpClipboardMonitor();

class _NoOpClipboardMonitor extends ClipboardMonitor {
  @override
  Stream<String> get onClipboardChanged => const Stream.empty();

  @override
  Future<void> setClipboard(String text) async {
    throw UnsupportedError('Clipboard not supported on this platform');
  }

  @override
  void dispose() {}
}
