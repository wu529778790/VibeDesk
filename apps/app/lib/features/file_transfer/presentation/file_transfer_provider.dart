import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logger.dart';
import '../domain/file_transfer_state.dart';

const _chunkSize = 16 * 1024; // 16 KB
const _bufferedAmountThreshold = 1024 * 1024; // 1 MB
const _binaryPrefixFile = 0x02;

class FileTransferNotifier extends StateNotifier<List<FileTransferProgress>> {
  final Map<String, List<Uint8List>> _receiveBuffers = {};
  final Map<String, String> _receiveFileNames = {};
  final Map<String, int> _receiveTotalSizes = {};
  final Map<String, int> _receiveTransferred = {};
  final Set<String> _cancelled = {};

  // Callback to save received files (set by UI layer)
  void Function(ReceivedFile file)? onSaveFile;

  FileTransferNotifier() : super(const []);

  void handleTextMessage(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'file_transfer_start':
        _onTransferStart(json);
      case 'file_transfer_end':
        _onTransferEnd(json);
      case 'file_transfer_cancel':
        _onTransferCancel(json);
    }
  }

  void handleBinaryMessage(Uint8List data) {
    if (data.isEmpty || data[0] != _binaryPrefixFile) return;
    // Format: [0x02][transfer_id_length as 1 byte][transfer_id bytes][chunk data]
    if (data.length < 2) return;
    final idLen = data[1];
    if (data.length < 2 + idLen) return;
    final transferId = String.fromCharCodes(data.sublist(2, 2 + idLen));
    final chunk = data.sublist(2 + idLen);

    if (_cancelled.contains(transferId)) return;

    (_receiveBuffers[transferId] ??= []).add(chunk);
    _receiveTransferred[transferId] =
        (_receiveTransferred[transferId] ?? 0) + chunk.length;

    _updateReceiveProgress(transferId);
  }

  Future<void> sendFile(String filePath, RTCDataChannel channel) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final fileName = filePath.split(Platform.pathSeparator).last;
    final fileSize = await file.length();
    final transferId = const Uuid().v4();

    state = [
      ...state,
      FileTransferProgress(
        transferId: transferId,
        fileName: fileName,
        totalBytes: fileSize,
        transferredBytes: 0,
        direction: TransferDirection.sending,
      ),
    ];

    // Send start message
    channel.send(RTCDataChannelMessage(jsonEncode({
      'type': 'file_transfer_start',
      'transfer_id': transferId,
      'name': fileName,
      'size': fileSize,
    })));

    // Read file and send chunks
    final randomAccessFile = await file.open();
    try {
      int offset = 0;
      while (offset < fileSize) {
        if (_cancelled.contains(transferId)) {
          _removeTransfer(transferId);
          channel.send(RTCDataChannelMessage(jsonEncode({
            'type': 'file_transfer_cancel',
            'transfer_id': transferId,
          })));
          return;
        }

        // Backpressure: wait if buffer is too full
        while ((channel.bufferedAmount ?? 0) > _bufferedAmountThreshold) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        final remaining = fileSize - offset;
        final readSize = remaining < _chunkSize ? remaining : _chunkSize;
        final bytes = await randomAccessFile.read(readSize);

        // Build binary frame: [0x02][id_length][transfer_id][chunk_data]
        final idBytes = Uint8List.fromList(transferId.codeUnits);
        final frame = BytesBuilder();
        frame.addByte(_binaryPrefixFile);
        frame.addByte(idBytes.length);
        frame.add(idBytes);
        frame.add(bytes);
        channel.send(RTCDataChannelMessage.fromBinary(frame.toBytes()));

        offset += readSize;

        _updateSendProgress(transferId, offset);
      }
    } finally {
      await randomAccessFile.close();
    }

    // Send end message
    channel.send(RTCDataChannelMessage(jsonEncode({
      'type': 'file_transfer_end',
      'transfer_id': transferId,
    })));

    if (!_cancelled.contains(transferId)) {
      _removeTransfer(transferId);
    }
  }

  void cancelTransfer(String transferId, RTCDataChannel? channel) {
    _cancelled.add(transferId);
    _removeTransfer(transferId);

    if (channel != null) {
      channel.send(RTCDataChannelMessage(jsonEncode({
        'type': 'file_transfer_cancel',
        'transfer_id': transferId,
      })));
    }
  }

  void _onTransferStart(Map<String, dynamic> json) {
    final transferId = json['transfer_id'] as String;
    final name = json['name'] as String;
    final size = (json['size'] as num).toInt();

    _receiveBuffers[transferId] = [];
    _receiveFileNames[transferId] = name;
    _receiveTotalSizes[transferId] = size;
    _receiveTransferred[transferId] = 0;

    state = [
      ...state,
      FileTransferProgress(
        transferId: transferId,
        fileName: name,
        totalBytes: size,
        transferredBytes: 0,
        direction: TransferDirection.receiving,
      ),
    ];
    Logger.info('File transfer start: $name ($size bytes)');
  }

  void _onTransferEnd(Map<String, dynamic> json) {
    final transferId = json['transfer_id'] as String;

    if (_cancelled.contains(transferId)) {
      _cleanupReceive(transferId);
      return;
    }

    final buffers = _receiveBuffers.remove(transferId);
    final name = _receiveFileNames.remove(transferId);
    _receiveTotalSizes.remove(transferId);
    _receiveTransferred.remove(transferId);

    if (buffers != null && name != null) {
      final builder = BytesBuilder();
      for (final chunk in buffers) {
        builder.add(chunk);
      }
      final data = builder.toBytes();
      Logger.info('File transfer complete: $name (${data.length} bytes)');
      onSaveFile?.call(ReceivedFile(fileName: name, data: data));
    }

    _removeTransfer(transferId);
  }

  void _onTransferCancel(Map<String, dynamic> json) {
    final transferId = json['transfer_id'] as String;
    _cancelled.add(transferId);
    _cleanupReceive(transferId);
    _removeTransfer(transferId);
  }

  void _updateSendProgress(String transferId, int transferred) {
    state = [
      for (final t in state)
        if (t.transferId == transferId && t.direction == TransferDirection.sending)
          t.copyWith(transferredBytes: transferred)
        else
          t,
    ];
  }

  void _updateReceiveProgress(String transferId) {
    final transferred = _receiveTransferred[transferId] ?? 0;
    state = [
      for (final t in state)
        if (t.transferId == transferId && t.direction == TransferDirection.receiving)
          t.copyWith(transferredBytes: transferred)
        else
          t,
    ];
  }

  void _removeTransfer(String transferId) {
    state = state.where((t) => t.transferId != transferId).toList();
  }

  void _cleanupReceive(String transferId) {
    _receiveBuffers.remove(transferId);
    _receiveFileNames.remove(transferId);
    _receiveTotalSizes.remove(transferId);
    _receiveTransferred.remove(transferId);
  }
}

final fileTransferProvider =
    StateNotifierProvider<FileTransferNotifier, List<FileTransferProgress>>(
  (ref) => FileTransferNotifier(),
);
