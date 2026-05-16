import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../logger.dart';
import 'audio_capturer.dart';

const _audclntStreamflagsLoopback = 0x00020000;
const _reftimesPerSec = 10000000;

class Win32AudioCapturer extends AudioCapturer {
  IMMDeviceEnumerator? _enumerator;
  IMMDevice? _device;
  IAudioClient? _audioClient;
  IAudioCaptureClient? _captureClient;
  Pointer<WAVEFORMATEX>? _mixFormat;

  StreamController<Uint8List>? _controller;
  bool _running = false;

  @override
  Stream<Uint8List> start() {
    _controller = StreamController<Uint8List>.broadcast();
    _running = true;
    _captureLoop();
    return _controller!.stream;
  }

  Future<void> _captureLoop() async {
    try {
      _initWASAPI();
    } catch (e) {
      Logger.error('WASAPI init failed', e);
      _controller?.addError(e);
      return;
    }

    final format = _mixFormat!.ref;
    final srcChannels = format.nChannels;
    final srcSampleRate = format.nSamplesPerSec;
    final srcBitsPerSample = format.wBitsPerSample;
    final bytesPerSample = srcBitsPerSample ~/ 8;

    Logger.info(
        'WASAPI capturing: ${srcSampleRate}Hz ${srcBitsPerSample}bit ${srcChannels}ch');

    while (_running) {
      try {
        final packetSize = _captureClient!.getNextPacketSize();
        if (packetSize == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
          continue;
        }

        final ppData = calloc<Pointer<Uint8>>();
        final pNumFrames = calloc<Uint32>();
        final pFlags = calloc<Uint32>();

        try {
          _captureClient!
              .getBuffer(ppData, pNumFrames, pFlags, nullptr, nullptr);
          final numFrames = pNumFrames.value;
          final flags = pFlags.value;

          if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) == 0 &&
              numFrames > 0 &&
              !_controller!.isClosed) {
            final byteCount = numFrames * srcChannels * bytesPerSample;
            final rawBuffer =
                Uint8List.fromList(ppData.value.asTypedList(byteCount));

            final pcm16 = _convertTo16kMono(
              rawBuffer,
              srcSampleRate,
              srcChannels,
              bytesPerSample,
            );
            _controller!.add(pcm16);
          }

          _captureClient!.releaseBuffer(numFrames);
        } finally {
          calloc.free(ppData);
          calloc.free(pNumFrames);
          calloc.free(pFlags);
        }
      } catch (e) {
        if (_running) {
          Logger.error('WASAPI capture error', e);
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    }
  }

  void _initWASAPI() {
    CoInitializeEx(COINIT_MULTITHREADED);

    final clsid = MMDeviceEnumerator.toNative();
    try {
      _enumerator =
          CoCreateInstance<IMMDeviceEnumerator>(clsid, null, CLSCTX_ALL);
    } finally {
      free(clsid);
    }

    _device = _enumerator!.getDefaultAudioEndpoint(eRender, eConsole);
    if (_device == null) {
      throw StateError('No default audio render device found');
    }

    _audioClient =
        _device!.activate<IAudioClient>(CLSCTX_INPROC_SERVER, nullptr);
    _mixFormat = _audioClient!.getMixFormat();

    _audioClient!.initialize(
      AUDCLNT_SHAREMODE_SHARED,
      _audclntStreamflagsLoopback,
      _reftimesPerSec,
      0,
      _mixFormat!,
      nullptr,
    );

    _captureClient = _audioClient!.getService<IAudioCaptureClient>();
    _audioClient!.start();

    Logger.info('WASAPI loopback capture started');
  }

  Uint8List _convertTo16kMono(
    Uint8List raw,
    int srcSampleRate,
    int srcChannels,
    int bytesPerSample,
  ) {
    final srcFrames = raw.length ~/ (srcChannels * bytesPerSample);
    final downsampleRatio = srcSampleRate ~/ 16000;
    if (downsampleRatio == 0) return Uint8List(0);
    final dstFrames = srcFrames ~/ downsampleRatio;

    final dst = Int16List(dstFrames);

    if (bytesPerSample == 4 && srcChannels == 2) {
      final srcFloat = Float32List.sublistView(raw);
      for (var i = 0; i < dstFrames; i++) {
        final srcIdx = i * downsampleRatio * 2;
        if (srcIdx + 1 < srcFloat.length) {
          final mono = (srcFloat[srcIdx] + srcFloat[srcIdx + 1]) / 2.0;
          dst[i] = (mono.clamp(-1.0, 1.0) * 32767).round();
        }
      }
    } else if (bytesPerSample == 2 && srcChannels == 2) {
      final srcInt = Int16List.sublistView(raw);
      for (var i = 0; i < dstFrames; i++) {
        final srcIdx = i * downsampleRatio * 2;
        if (srcIdx + 1 < srcInt.length) {
          dst[i] = ((srcInt[srcIdx] + srcInt[srcIdx + 1]) ~/ 2);
        }
      }
    } else if (bytesPerSample == 4 && srcChannels == 1) {
      final srcFloat = Float32List.sublistView(raw);
      for (var i = 0; i < dstFrames; i++) {
        final srcIdx = i * downsampleRatio;
        if (srcIdx < srcFloat.length) {
          dst[i] = (srcFloat[srcIdx].clamp(-1.0, 1.0) * 32767).round();
        }
      }
    } else {
      return Uint8List(dstFrames * 2);
    }

    return Uint8List.sublistView(dst);
  }

  @override
  void stop() {
    _running = false;
    try {
      _audioClient?.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
    _controller?.close();
    _captureClient = null;
    _audioClient = null;
    _device = null;
    _enumerator = null;
    if (_mixFormat != null) {
      try {
        CoTaskMemFree(_mixFormat!.cast());
      } catch (_) {}
      _mixFormat = null;
    }
    try {
      CoUninitialize();
    } catch (_) {}
  }
}
