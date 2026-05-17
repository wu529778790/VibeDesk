import 'dart:typed_data';

enum TransferDirection { sending, receiving }

class FileTransferProgress {
  final String transferId;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final TransferDirection direction;

  const FileTransferProgress({
    required this.transferId,
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    required this.direction,
  });

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0;

  FileTransferProgress copyWith({int? transferredBytes}) {
    return FileTransferProgress(
      transferId: transferId,
      fileName: fileName,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      direction: direction,
    );
  }
}

class ReceivedFile {
  final String fileName;
  final Uint8List data;

  const ReceivedFile({required this.fileName, required this.data});
}
