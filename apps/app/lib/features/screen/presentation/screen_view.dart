import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'screen_provider.dart';

class ScreenView extends ConsumerWidget {
  const ScreenView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderer = ref.watch(screenProvider);

    if (renderer == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for stream...'),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: RTCVideoView(
        renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      ),
    );
  }
}
