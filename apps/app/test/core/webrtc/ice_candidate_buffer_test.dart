import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:app/core/webrtc/ice_candidate_buffer.dart';

RTCIceCandidate _makeCandidate(int id) {
  return RTCIceCandidate(
    'candidate:$id 1 UDP 2130706431 192.168.1.1 ${12345 + id} typ host',
    '0',
    id,
  );
}

void main() {
  group('IceCandidateBuffer', () {
    late IceCandidateBuffer buffer;

    setUp(() {
      buffer = IceCandidateBuffer();
    });

    test('starts not ready with empty pending list', () {
      expect(buffer.isReady, isFalse);
      expect(buffer.pendingCount, 0);
    });

    test('buffers candidates before remote description is set', () {
      final c1 = _makeCandidate(1);
      final c2 = _makeCandidate(2);

      final buffered1 = buffer.add(c1);
      final buffered2 = buffer.add(c2);

      expect(buffered1, isTrue);
      expect(buffered2, isTrue);
      expect(buffer.pendingCount, 2);
      expect(buffer.isReady, isFalse);
    });

    test('drain returns all buffered candidates and marks ready', () {
      final c1 = _makeCandidate(1);
      final c2 = _makeCandidate(2);
      buffer.add(c1);
      buffer.add(c2);

      final drained = buffer.drain();

      expect(buffer.isReady, isTrue);
      expect(drained.length, 2);
      expect(drained[0].candidate, contains('12346'));
      expect(drained[1].candidate, contains('12347'));
      expect(buffer.pendingCount, 0);
    });

    test('returns false after remote description is set (pass-through)', () {
      buffer.drain(); // Mark as ready

      final buffered = buffer.add(_makeCandidate(1));

      expect(buffered, isFalse);
      expect(buffer.pendingCount, 0);
    });

    test('reset allows buffering again after drain', () {
      buffer.add(_makeCandidate(1));
      buffer.drain();
      expect(buffer.isReady, isTrue);

      buffer.reset();

      expect(buffer.isReady, isFalse);
      expect(buffer.pendingCount, 0);

      final buffered = buffer.add(_makeCandidate(2));
      expect(buffered, isTrue);
      expect(buffer.pendingCount, 1);
    });

    test('handles rapid candidates followed by drain', () async {
      // Simulate the race condition: many candidates arrive before drain
      for (var i = 0; i < 10; i++) {
        buffer.add(_makeCandidate(i));
      }
      expect(buffer.pendingCount, 10);

      final drained = buffer.drain();
      expect(drained.length, 10);
      expect(buffer.pendingCount, 0);
      expect(buffer.isReady, isTrue);

      // New candidates go directly
      expect(buffer.add(_makeCandidate(99)), isFalse);
    });
  });
}
