import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recording_state.dart';
import 'recording_provider.dart';

class RecordingControls extends ConsumerWidget {
  const RecordingControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recording = ref.watch(recordingProvider);

    if (recording.status == RecordingStatus.idle) {
      return MouseRegion(
        child: Material(
          color: Colors.transparent,
          child: IconButton(
            icon: const Icon(Icons.fiber_manual_record,
                color: Colors.white70, size: 24),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            tooltip: 'Start recording',
            onPressed: () =>
                ref.read(recordingProvider.notifier).startRecording(
                      // Video track is set externally via the provider
                      // after calling setVideoTrack
                      null as dynamic,
                      '', // path set externally
                    ),
          ),
        ),
      );
    }

    final duration = recording.duration ?? Duration.zero;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return MouseRegion(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$minutes:$seconds',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () =>
                  ref.read(recordingProvider.notifier).stopRecording(),
              child: const Icon(Icons.stop, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
