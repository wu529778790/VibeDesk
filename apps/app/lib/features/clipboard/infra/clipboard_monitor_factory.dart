export '../domain/clipboard_sync.dart';
export 'clipboard_monitor_stub.dart'
    if (dart.library.io) 'clipboard_monitor_native.dart';
