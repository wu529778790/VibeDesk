import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../room/presentation/session_provider.dart';
import '../domain/file_transfer_state.dart';
import 'file_transfer_provider.dart';

class FileTransferOverlay extends ConsumerWidget {
  const FileTransferOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(fileTransferProvider);
    if (transfers.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in transfers)
            _TransferCard(
              transfer: t,
              onCancel: () {
                final dc = ref.read(sessionProvider.notifier).dataChannel;
                ref
                    .read(fileTransferProvider.notifier)
                    .cancelTransfer(t.transferId, dc);
              },
            ),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final FileTransferProgress transfer;
  final VoidCallback onCancel;

  const _TransferCard({required this.transfer, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isSending = transfer.direction == TransferDirection.sending;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSending ? Icons.upload : Icons.download,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  transfer.fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(transfer.progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onCancel,
                child: const Icon(Icons.close, color: Colors.white54, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: transfer.progress,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSending ? Colors.blue : Colors.green,
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
