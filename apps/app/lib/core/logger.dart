import 'dart:developer' as developer;

class Logger {
  static void info(String message) {
    developer.log(message, name: 'VibeDesk', level: 800);
  }

  static void warning(String message) {
    developer.log(message, name: 'VibeDesk', level: 900);
  }

  static void error(String message, [Object? error]) {
    developer.log(message, name: 'VibeDesk', level: 1000, error: error);
  }
}
