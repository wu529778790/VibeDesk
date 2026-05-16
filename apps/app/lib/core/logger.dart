import 'dart:developer' as developer;
import 'package:sentry_flutter/sentry_flutter.dart';

class Logger {
  static void info(String message) {
    developer.log(message, name: 'VibeDesk', level: 800);
    Sentry.addBreadcrumb(Breadcrumb(
      level: SentryLevel.info,
      message: message,
    ));
  }

  static void warning(String message) {
    developer.log(message, name: 'VibeDesk', level: 900);
    Sentry.addBreadcrumb(Breadcrumb(
      level: SentryLevel.warning,
      message: message,
    ));
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(message, name: 'VibeDesk', level: 1000, error: error);
    Sentry.captureException(
      error ?? Exception(message),
      stackTrace: stackTrace,
    );
  }
}
