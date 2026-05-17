import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../infra/clipboard_monitor_factory.dart';

const _prefsKey = 'clipboard_sync_enabled';

class ClipboardSyncNotifier extends StateNotifier<bool> {
  ClipboardMonitor? _monitor;
  StreamSubscription<String>? _subscription;
  void Function(String text)? _sendCallback;
  DateTime _lastSetTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _started = false;

  ClipboardSyncNotifier() : super(false);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefsKey) ?? false;
  }

  void start(void Function(String text) sendCallback) {
    if (_started) return;
    _started = true;
    _sendCallback = sendCallback;
    _monitor = createPlatformClipboardMonitor();
    _subscription = _monitor!.onClipboardChanged.listen(_onLocalClipboardChanged);
  }

  void _onLocalClipboardChanged(String text) {
    if (!state) return;
    final now = DateTime.now();
    if (now.difference(_lastSetTime).inMilliseconds < 500) return;
    _sendCallback?.call(text);
  }

  Future<void> handleRemoteClipboard(String text) async {
    if (!state) return;
    _lastSetTime = DateTime.now();
    await _monitor?.setClipboard(text);
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _monitor?.dispose();
    super.dispose();
  }
}

final clipboardSyncProvider =
    StateNotifierProvider<ClipboardSyncNotifier, bool>(
  (ref) {
    final notifier = ClipboardSyncNotifier();
    notifier.init();
    return notifier;
  },
);
