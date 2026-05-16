import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../logger.dart';
import 'audio_player.dart';

// --- AudioToolbox FFI bindings ---

final _audioToolbox = DynamicLibrary.open('/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox');

// OSStatus AudioQueueNewOutput(
//   const AudioStreamBasicDescription *inFormat,
//   AudioQueueOutputCallback inCallbackProc,
//   void *inUserData,
//   CFRunLoopRef inCallbackRunLoop,
//   CFStringRef inCallbackRunLoopMode,
//   UInt32 inFlags,
//   AudioQueueRef *outAQ
// );
final _audioQueueNewOutput = _audioToolbox.lookupFunction<
    Int32 Function(
        Pointer<AudioStreamBasicDescription>,
        Pointer<NativeFunction<AudioQueueOutputCallback>>,
        Pointer,
        Pointer,
        Pointer,
        Uint32,
        Pointer<Pointer>),
    int Function(Pointer<AudioStreamBasicDescription>,
        Pointer<NativeFunction<AudioQueueOutputCallback>>, Pointer, Pointer, Pointer, int, Pointer<Pointer>)>('AudioQueueNewOutput');

// OSStatus AudioQueueAllocateBuffer(AudioQueueRef inAQ, UInt32 inBufferByteSize, AudioQueueBufferRef *outBuffer)
final _audioQueueAllocateBuffer = _audioToolbox.lookupFunction<
    Int32 Function(Pointer, Uint32, Pointer<Pointer<AudioQueueBuffer>>),
    int Function(Pointer, int, Pointer<Pointer<AudioQueueBuffer>>)>(
    'AudioQueueAllocateBuffer');

// OSStatus AudioQueueEnqueueBuffer(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, UInt32 inNumPacketDescs, const AudioStreamPacketDescription *inPacketDescs)
final _audioQueueEnqueueBuffer = _audioToolbox.lookupFunction<
    Int32 Function(Pointer, Pointer<AudioQueueBuffer>, Uint32, Pointer),
    int Function(Pointer, Pointer<AudioQueueBuffer>, int, Pointer)>(
    'AudioQueueEnqueueBuffer');

// OSStatus AudioQueueStart(AudioQueueRef inAQ, const AudioTimeStamp *inStartTime)
final _audioQueueStart = _audioToolbox.lookupFunction<
    Int32 Function(Pointer, Pointer), int Function(Pointer, Pointer)>(
    'AudioQueueStart');

// OSStatus AudioQueueStop(AudioQueueRef inAQ, Boolean inImmediate)
final _audioQueueStop = _audioToolbox.lookupFunction<
    Int32 Function(Pointer, Uint8), int Function(Pointer, int)>(
    'AudioQueueStop');

// OSStatus AudioQueueDispose(AudioQueueRef inAQ, Boolean inImmediate)
final _audioQueueDispose = _audioToolbox.lookupFunction<
    Int32 Function(Pointer, Uint8), int Function(Pointer, int)>(
    'AudioQueueDispose');

// Callback type: void callback(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer)
typedef AudioQueueOutputCallback = Void Function(Pointer, Pointer, Pointer<AudioQueueBuffer>);

// --- Structs ---

/// AudioStreamBasicDescription
final class AudioStreamBasicDescription extends Struct {
  @Float()
  external double mSampleRate;
  @Uint32()
  external int mFormatID;
  @Uint32()
  external int mFormatFlags;
  @Uint32()
  external int mBytesPerPacket;
  @Uint32()
  external int mFramesPerPacket;
  @Uint32()
  external int mBytesPerFrame;
  @Uint32()
  external int mChannelsPerFrame;
  @Uint32()
  external int mBitsPerChannel;
  @Uint32()
  external int mReserved;
}

/// AudioQueueBuffer
final class AudioQueueBuffer extends Struct {
  @Uint32()
  external int mAudioQueueBytesCapacity;
  external Pointer<Void> mAudioQueueData;
  @Uint32()
  external int mAudioQueueByteSize;
  @Uint32()
  external int mPacketDescriptionCapacity;
  external Pointer<Void> mPacketDescriptions;
  @Uint32()
  external int mPacketDescriptionCount;
}

// Audio format IDs and flags
const _kAudioFormatLinearPCM = 0x6C70636D; // 'lpcm'
const _kAudioFormatFlagIsSignedInteger = 0x00000002;
const _kAudioFormatFlagIsPacked = 0x00000008;
const _kNoError = 0;

class MacosAudioPlayer extends AudioPlayer {
  Pointer? _queueRef;
  final List<Pointer<AudioQueueBuffer>> _buffers = [];
  final List<Uint8List> _pendingChunks = [];
  bool _started = false;
  int _bytesPerFrame = 2;

  // Keep callback pointer alive (prevent GC)
  late final Pointer<NativeFunction<AudioQueueOutputCallback>> _callbackPtr;

  // Store self-pointer for native callback
  static MacosAudioPlayer? _instance;

  @override
  void init({
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    _instance = this;
    _bytesPerFrame = (bitsPerSample ~/ 8) * channels;

    final format = calloc<AudioStreamBasicDescription>();
    format.ref.mSampleRate = sampleRate.toDouble();
    format.ref.mFormatID = _kAudioFormatLinearPCM;
    format.ref.mFormatFlags =
        _kAudioFormatFlagIsSignedInteger | _kAudioFormatFlagIsPacked;
    format.ref.mBytesPerPacket = _bytesPerFrame;
    format.ref.mFramesPerPacket = 1;
    format.ref.mBytesPerFrame = _bytesPerFrame;
    format.ref.mChannelsPerFrame = channels;
    format.ref.mBitsPerChannel = bitsPerSample;
    format.ref.mReserved = 0;

    _callbackPtr = Pointer.fromFunction<AudioQueueOutputCallback>(_outputCallback);

    final queueOut = calloc<Pointer>();
    final status = _audioQueueNewOutput(
      format,
      _callbackPtr,
      nullptr, // userData
      nullptr, // runLoop (default)
      nullptr, // runLoopMode (default)
      0,
      queueOut,
    );
    calloc.free(format);

    if (status != _kNoError) {
      calloc.free(queueOut);
      Logger.error('AudioQueueNewOutput failed: $status');
      return;
    }

    _queueRef = queueOut.value;
    calloc.free(queueOut);

    // Allocate 4 buffers of ~20ms each
    final bufferByteSize = sampleRate * _bytesPerFrame ~/ 50; // 20ms
    for (var i = 0; i < 4; i++) {
      final bufOut = calloc<Pointer<AudioQueueBuffer>>();
      _audioQueueAllocateBuffer(_queueRef!, bufferByteSize, bufOut);
      _buffers.add(bufOut.value);
      calloc.free(bufOut);
    }

    Logger.info('macOS AudioQueue initialized: ${sampleRate}Hz ${bitsPerSample}bit ${channels}ch');
  }

  static void _outputCallback(Pointer userData, Pointer queue, Pointer<AudioQueueBuffer> buffer) {
    final self = _instance;
    if (self == null || self._queueRef == null) return;

    // Fill buffer from pending chunks
    var offset = 0;
    final capacity = buffer.ref.mAudioQueueBytesCapacity;

    while (offset < capacity && self._pendingChunks.isNotEmpty) {
      final chunk = self._pendingChunks.first;
      final remaining = capacity - offset;
      if (chunk.length <= remaining) {
        // Copy entire chunk
        buffer.ref.mAudioQueueData.cast<Uint8>().asTypedList(chunk.length).setAll(0, chunk);
        offset += chunk.length;
        self._pendingChunks.removeAt(0);
      } else {
        // Partial copy
        buffer.ref.mAudioQueueData.cast<Uint8>().asTypedList(remaining).setAll(0, chunk.sublist(0, remaining));
        offset += remaining;
        self._pendingChunks[0] = chunk.sublist(remaining);
      }
    }

    buffer.ref.mAudioQueueByteSize = offset;

    // Fill remaining with silence if no data
    if (offset < capacity) {
      buffer.ref.mAudioQueueData.cast<Uint8>().asTypedList(capacity - offset).fillRange(0, capacity - offset, 0);
    }

    _audioQueueEnqueueBuffer(queue, buffer, 0, nullptr);
  }

  @override
  void feed(Uint8List pcmChunk) {
    _pendingChunks.add(pcmChunk);

    // Cap buffer to avoid memory growth (keep ~200ms max)
    final maxBytes = 16000 * _bytesPerFrame ~/ 5;
    while (_totalPendingBytes() > maxBytes) {
      _pendingChunks.removeAt(0);
    }

    if (!_started && _queueRef != null) {
      // Prime: enqueue all buffers to start playback
      for (final buf in _buffers) {
        _outputCallback(nullptr, _queueRef!, buf);
      }
      final status = _audioQueueStart(_queueRef!, nullptr);
      if (status == _kNoError) {
        _started = true;
        Logger.info('AudioQueue playback started');
      }
    }
  }

  int _totalPendingBytes() {
    var total = 0;
    for (final chunk in _pendingChunks) {
      total += chunk.length;
    }
    return total;
  }

  @override
  void stop() {
    if (_started && _queueRef != null) {
      _audioQueueStop(_queueRef!, 1);
      _started = false;
    }
  }

  @override
  void dispose() {
    stop();
    if (_queueRef != null) {
      _audioQueueDispose(_queueRef!, 1);
      _queueRef = null;
    }
    _buffers.clear();
    _pendingChunks.clear();
    if (_instance == this) {
      _instance = null;
    }
  }
}
