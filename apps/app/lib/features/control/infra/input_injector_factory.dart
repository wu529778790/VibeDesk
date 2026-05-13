import '../domain/input_injector.dart';
import 'input_injector_stub.dart'
    if (dart.library.io) 'input_injector_native.dart';

InputInjector createInputInjector() => createPlatformInputInjector();
