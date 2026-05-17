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
import 'package:slock_app/core/realtime/scope_patterns.dart';

/// Helper matching the inline extraction logic used in realtime bindings.
String? _extractServer(String scopeKey) {
  final match = serverScopePattern.firstMatch(scopeKey);
  return match?.group(1);
}

/// Helper matching the inline extraction logic used in realtime bindings.
String? _extractChannel(String scopeKey) {
  final match = channelScopePattern.firstMatch(scopeKey);
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
    );

    test(
      'extracts server ID from prefixed scope key',
      () {
        expect(_extractServer('org/server:abc123'), equals('abc123'));
      },
    );

    test(
      'returns null when scope key has no server prefix',
      () {
        expect(_extractServer('channel:xyz'), isNull);
      },
    );

    test(
      'extracts server ID with complex path prefix',
      () {
        expect(
          _extractServer('workspace/team/server:s1'),
          equals('s1'),
        );
      },
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
    );

    test(
      'extracts channel ID from prefixed scope key',
      () {
        expect(_extractChannel('org/channel:xyz789'), equals('xyz789'));
      },
    );

    test(
      'returns null when scope key has no channel prefix',
      () {
        expect(_extractChannel('server:abc'), isNull);
      },
    );

    test(
      'extracts channel ID with complex path prefix',
      () {
        expect(
          _extractChannel('workspace/team/channel:c1'),
          equals('c1'),
        );
      },
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
    );

    test(
      'empty string returns null for channel extraction',
      () {
        expect(_extractChannel(''), isNull);
      },
    );

    test(
      'string with no recognized prefix returns null',
      () {
        expect(_extractServer('random-string'), isNull);
        expect(_extractChannel('random-string'), isNull);
      },
    );

    test(
      'multi-segment scope key returns correct match for each pattern',
      () {
        const multiSegment = 'server:a/channel:b';
        expect(_extractServer(multiSegment), equals('a'));
        expect(_extractChannel(multiSegment), equals('b'));
      },
    );

    test(
      'server ID stops at slash boundary',
      () {
        expect(_extractServer('server:abc/extra'), equals('abc'));
      },
    );

    test(
      'channel ID stops at slash boundary',
      () {
        expect(_extractChannel('channel:xyz/extra'), equals('xyz'));
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-REGEXP-CONST: Shared constants exist and are RegExp
  // -----------------------------------------------------------------------
  group('INV-REGEXP-CONST: shared constants', () {
    test(
      'serverScopePattern is exported and is a RegExp instance',
      () {
        // Imported from lib/core/realtime/scope_patterns.dart.
        // This test fails if the export is removed or renamed.
        expect(serverScopePattern, isA<RegExp>());
      },
    );

    test(
      'channelScopePattern is exported and is a RegExp instance',
      () {
        // Imported from lib/core/realtime/scope_patterns.dart.
        // This test fails if the export is removed or renamed.
        expect(channelScopePattern, isA<RegExp>());
      },
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
            serverScopePattern.firstMatch(input)?.group(1),
            equals(inline.firstMatch(input)?.group(1)),
            reason: 'Mismatch for input: $input',
          );
        }
      },
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
            channelScopePattern.firstMatch(input)?.group(1),
            equals(inline.firstMatch(input)?.group(1)),
            reason: 'Mismatch for input: $input',
          );
        }
      },
    );
  });
}
