// ignore_for_file: prefer_const_constructors

// =============================================================================
// #694 — Cold-start deep link dedup guard
//
// Tests the DeepLinkDedupGuard logic that prevents duplicate route pushes when
// Android OEMs re-emit the cold-start launch intent on uriLinkStream.
//
// Both race orderings are tested:
// 1. getInitialLink resolves first, stream re-emits same URI → dispatched once.
// 2. Stream fires first (OEM race), getInitialLink resolves same URI → once.
// Plus: different URIs, no cold-start, subsequent events always pass through.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/deep_link/deep_link_lifecycle_binding.dart';

void main() {
  group('#694 — DeepLinkDedupGuard', () {
    late DeepLinkDedupGuard guard;

    setUp(() {
      guard = DeepLinkDedupGuard();
    });

    group('Race order 1: getInitialLink resolves first, stream re-emits', () {
      test('initial dispatches, duplicate stream event is blocked', () {
        final uri = Uri.parse('https://app.slock.ai/invite/abc123');

        // getInitialLink resolves first.
        expect(guard.shouldDispatchInitial(uri), isTrue);

        // Stream re-emits same URI → blocked.
        expect(guard.shouldDispatchStream(uri), isFalse);
      });
    });

    group('Race order 2: stream fires first, getInitialLink resolves later',
        () {
      test('stream dispatches, duplicate initial is blocked', () {
        final uri = Uri.parse('https://app.slock.ai/invite/abc123');

        // Stream fires first (OEM race).
        expect(guard.shouldDispatchStream(uri), isTrue);

        // getInitialLink resolves same URI → blocked.
        expect(guard.shouldDispatchInitial(uri), isFalse);
      });
    });

    group('Integration — exactly-once dispatch', () {
      test(
        'order 1: initial first + stream duplicate → total dispatch = 1',
        () {
          final uri = Uri.parse('slock://servers/s1/channels/c1');
          final dispatched = <Uri>[];

          // Simulate: getInitialLink resolves.
          if (guard.shouldDispatchInitial(uri)) {
            dispatched.add(uri);
          }

          // Simulate: stream re-emits same URI.
          if (guard.shouldDispatchStream(uri)) {
            dispatched.add(uri);
          }

          expect(dispatched, hasLength(1));
          expect(dispatched.first, uri);
        },
      );

      test(
        'order 2: stream first + initial duplicate → total dispatch = 1',
        () {
          final uri = Uri.parse('slock://servers/s1/channels/c1');
          final dispatched = <Uri>[];

          // Simulate: stream fires first (OEM race).
          if (guard.shouldDispatchStream(uri)) {
            dispatched.add(uri);
          }

          // Simulate: getInitialLink resolves same URI.
          if (guard.shouldDispatchInitial(uri)) {
            dispatched.add(uri);
          }

          expect(dispatched, hasLength(1));
          expect(dispatched.first, uri);
        },
      );
    });

    group('Different URIs from each source', () {
      test('both dispatch when URIs differ', () {
        final initial = Uri.parse('https://app.slock.ai/invite/abc');
        final stream = Uri.parse('https://app.slock.ai/channels/ch1');

        // getInitialLink resolves with one URI.
        expect(guard.shouldDispatchInitial(initial), isTrue);

        // Stream fires different URI → also dispatches.
        expect(guard.shouldDispatchStream(stream), isTrue);
      });

      test('both dispatch when stream fires different URI first', () {
        final stream = Uri.parse('https://app.slock.ai/channels/ch1');
        final initial = Uri.parse('https://app.slock.ai/invite/abc');

        // Stream fires first with one URI.
        expect(guard.shouldDispatchStream(stream), isTrue);

        // getInitialLink resolves with different URI → also dispatches.
        expect(guard.shouldDispatchInitial(initial), isTrue);
      });
    });

    group('No cold-start link (getInitialLink returns null)', () {
      test('stream events dispatch normally', () {
        // getInitialLink returns null — no shouldDispatchInitial call.
        final uri = Uri.parse('https://app.slock.ai/invite/token');
        expect(guard.shouldDispatchStream(uri), isTrue);
      });
    });

    group('Subsequent stream events after first dedup', () {
      test('all pass through after first stream event consumed', () {
        final coldStart = Uri.parse('https://app.slock.ai/invite/abc');
        final subsequent = Uri.parse('https://app.slock.ai/channels/ch2');

        // Initial dispatches.
        guard.shouldDispatchInitial(coldStart);

        // First stream event (duplicate) → blocked.
        expect(guard.shouldDispatchStream(coldStart), isFalse);

        // Subsequent stream events always pass through.
        expect(guard.shouldDispatchStream(subsequent), isTrue);
        expect(guard.shouldDispatchStream(coldStart), isTrue);
      });

      test('subsequent events pass even when stream fired first', () {
        final uri = Uri.parse('https://app.slock.ai/invite/abc');
        final later = Uri.parse('https://app.slock.ai/other');

        // Stream fires first.
        guard.shouldDispatchStream(uri);

        // Initial blocked (duplicate).
        guard.shouldDispatchInitial(uri);

        // Subsequent stream events always pass through.
        expect(guard.shouldDispatchStream(later), isTrue);
        expect(guard.shouldDispatchStream(uri), isTrue);
      });
    });
  });
}
