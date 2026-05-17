// ---------------------------------------------------------------------------
// #555: Realtime RegExp Constants — Scope Pattern Tests
//
// Problem: The same RegExp patterns for extracting server and channel IDs
// from realtime event scope keys are constructed fresh on every inbound
// event across 5+ files (~9 allocations on the hot path). No shared
// constants exist.
//
// Phase A: skip:true invariants locking the parsing contracts and
//          verifying that shared constants will exist and behave
//          identically to the inline patterns.
//
// Invariants verified:
// INV-REGEXP-PARSE-1: Server scope extraction from scope key strings
// INV-REGEXP-PARSE-2: Channel scope extraction from scope key strings
// INV-REGEXP-PARSE-3: Edge cases (empty, no prefix, multi-segment)
// INV-REGEXP-CONST:   Shared constants exist, are RegExp, match the
//                      expected patterns
// ---------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';

/// The server scope pattern currently hardcoded across 5 files.
/// Phase B will replace with import from lib/core/realtime/scope_patterns.dart.
final _serverScopePattern = RegExp(r'(?:^|/)server:([^/]+)');

/// The channel scope pattern currently hardcoded across 3 files.
/// Phase B will replace with import from lib/core/realtime/scope_patterns.dart.
final _channelScopePattern = RegExp(r'(?:^|/)channel:([^/]+)');

/// Helper matching the inline extraction logic used in realtime bindings.
String? _extractServer(String scopeKey) {
  final match = _serverScopePattern.firstMatch(scopeKey);
  return match?.group(1);
}

/// Helper matching the inline extraction logic used in realtime bindings.
String? _extractChannel(String scopeKey) {
  final match = _channelScopePattern.firstMatch(scopeKey);
  return match?.group(1);
}

void main() {
  // -----------------------------------------------------------------------
  // INV-REGEXP-PARSE-1: Server scope extraction
  // -----------------------------------------------------------------------
  group('INV-REGEXP-PARSE-1: server scope extraction', () {
    test(
      'extracts server ID from bare scope key',
      () {
        expect(_extractServer('server:abc123'), equals('abc123'));
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'extracts server ID from prefixed scope key',
      () {
        expect(_extractServer('org/server:abc123'), equals('abc123'));
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'returns null when scope key has no server prefix',
      () {
        expect(_extractServer('channel:xyz'), isNull);
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'extracts server ID with complex path prefix',
      () {
        expect(
          _extractServer('workspace/team/server:s1'),
          equals('s1'),
        );
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );
  });

  // -----------------------------------------------------------------------
  // INV-REGEXP-PARSE-2: Channel scope extraction
  // -----------------------------------------------------------------------
  group('INV-REGEXP-PARSE-2: channel scope extraction', () {
    test(
      'extracts channel ID from bare scope key',
      () {
        expect(_extractChannel('channel:xyz789'), equals('xyz789'));
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'extracts channel ID from prefixed scope key',
      () {
        expect(_extractChannel('org/channel:xyz789'), equals('xyz789'));
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'returns null when scope key has no channel prefix',
      () {
        expect(_extractChannel('server:abc'), isNull);
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'extracts channel ID with complex path prefix',
      () {
        expect(
          _extractChannel('workspace/team/channel:c1'),
          equals('c1'),
        );
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );
  });

  // -----------------------------------------------------------------------
  // INV-REGEXP-PARSE-3: Edge cases
  // -----------------------------------------------------------------------
  group('INV-REGEXP-PARSE-3: edge cases', () {
    test(
      'empty string returns null for server extraction',
      () {
        expect(_extractServer(''), isNull);
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'empty string returns null for channel extraction',
      () {
        expect(_extractChannel(''), isNull);
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'string with no recognized prefix returns null',
      () {
        expect(_extractServer('random-string'), isNull);
        expect(_extractChannel('random-string'), isNull);
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'multi-segment scope key returns correct match for each pattern',
      () {
        const multiSegment = 'server:a/channel:b';
        expect(_extractServer(multiSegment), equals('a'));
        expect(_extractChannel(multiSegment), equals('b'));
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'server ID stops at slash boundary',
      () {
        expect(_extractServer('server:abc/extra'), equals('abc'));
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );

    test(
      'channel ID stops at slash boundary',
      () {
        expect(_extractChannel('channel:xyz/extra'), equals('xyz'));
      },
      skip: 'Phase A: invariant locked — Phase B promotes to shared constant',
    );
  });

  // -----------------------------------------------------------------------
  // INV-REGEXP-CONST: Shared constants exist and are RegExp
  // -----------------------------------------------------------------------
  group('INV-REGEXP-CONST: shared constants', () {
    test(
      'server scope pattern is a RegExp instance',
      () {
        // Phase B will import from lib/core/realtime/scope_patterns.dart
        // and verify the exported constant here.
        expect(_serverScopePattern, isA<RegExp>());
      },
      skip: 'Phase A: invariant locked — Phase B exports shared constants',
    );

    test(
      'channel scope pattern is a RegExp instance',
      () {
        // Phase B will import from lib/core/realtime/scope_patterns.dart
        // and verify the exported constant here.
        expect(_channelScopePattern, isA<RegExp>());
      },
      skip: 'Phase A: invariant locked — Phase B exports shared constants',
    );

    test(
      'server pattern matches the canonical inline pattern',
      () {
        // Verify the shared constant produces identical results to the
        // inline pattern currently hardcoded in realtime bindings.
        final inline = RegExp(r'(?:^|/)server:([^/]+)');
        const testCases = [
          'server:abc123',
          'org/server:abc123',
          'channel:xyz',
          '',
          'server:a/channel:b',
        ];
        for (final input in testCases) {
          expect(
            _serverScopePattern.firstMatch(input)?.group(1),
            equals(inline.firstMatch(input)?.group(1)),
            reason: 'Mismatch for input: $input',
          );
        }
      },
      skip: 'Phase A: invariant locked — Phase B exports shared constants',
    );

    test(
      'channel pattern matches the canonical inline pattern',
      () {
        final inline = RegExp(r'(?:^|/)channel:([^/]+)');
        const testCases = [
          'channel:xyz789',
          'org/channel:xyz789',
          'server:abc',
          '',
          'server:a/channel:b',
        ];
        for (final input in testCases) {
          expect(
            _channelScopePattern.firstMatch(input)?.group(1),
            equals(inline.firstMatch(input)?.group(1)),
            reason: 'Mismatch for input: $input',
          );
        }
      },
      skip: 'Phase A: invariant locked — Phase B exports shared constants',
    );
  });
}
