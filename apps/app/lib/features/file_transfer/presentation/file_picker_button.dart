import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../room/presentation/session_provider.dart';
import 'file_transfer_provider.dart';

class FilePickerButton extends ConsumerWidget {
  const FilePickerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.attach_file, color: Colors.white70, size: 24),
      style: IconButton.styleFrom(backgroundColor: Colors.black45),
      tooltip: 'Send file',
      onPressed: () async {
        final dc = ref.read(sessionProvider.notifier).dataChannel;
        if (dc == null) return;
        if (dc.state != RTCDataChannelState.RTCDataChannelOpen) return;

        final result = await FilePicker.platform.pickFiles();
        if (result == null || result.files.isEmpty) return;

        final filePath = result.files.single.path;
        if (filePath == null) return;

        ref.read(fileTransferProvider.notifier).sendFile(filePath, dc);
      },
    );
  }
}
