abstract class ClipboardMonitor {
  Stream<String> get onClipboardChanged;
  Future<void> setClipboard(String text);
  void dispose();
}
