import 'dart:io';

class AutoLaunchService {
  static const _macosBundleId = 'com.vibedesk.app';
  static const _windowsAppName = 'VibeDesk';

  static String get _plistPath =>
      '${Platform.environment['HOME']}/Library/LaunchAgents/$_macosBundleId.plist';

  static bool get isEnabled {
    if (Platform.isMacOS) {
      return File(_plistPath).existsSync();
    }
    if (Platform.isWindows) {
      final result = Process.runSync('reg', [
        'query',
        'HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run',
        '/v',
        _windowsAppName,
      ]);
      return result.exitCode == 0;
    }
    return false;
  }

  static Future<void> enable() async {
    if (Platform.isMacOS) {
      await _enableMacOS();
    } else if (Platform.isWindows) {
      await _enableWindows();
    }
  }

  static Future<void> disable() async {
    if (Platform.isMacOS) {
      final file = File(_plistPath);
      if (await file.exists()) await file.delete();
    } else if (Platform.isWindows) {
      await Process.run('reg', [
        'delete',
        'HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run',
        '/v',
        _windowsAppName,
        '/f',
      ]);
    }
  }

  static Future<void> _enableMacOS() async {
    final exePath = Platform.resolvedExecutable;
    final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$_macosBundleId</string>
    <key>ProgramArguments</key>
    <array>
        <string>$exePath</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>''';
    await File(_plistPath).writeAsString(plist);
  }

  static Future<void> _enableWindows() async {
    final exePath = Platform.resolvedExecutable;
    await Process.run('reg', [
      'add',
      'HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run',
      '/v',
      _windowsAppName,
      '/t',
      'REG_SZ',
      '/d',
      exePath,
      '/f',
    ]);
  }
}
