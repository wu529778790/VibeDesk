import 'dart:io';
import '../domain/input_injector.dart';
import 'win32_input_injector.dart';

InputInjector createPlatformInputInjector() {
  if (Platform.isWindows) {
    return Win32InputInjector();
  }
  throw UnsupportedError('Input injection not supported on ${Platform.operatingSystem}');
}
