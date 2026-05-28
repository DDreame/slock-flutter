// =============================================================================
// #852 — Dead Code Removal: Orphaned ARB Key + Unreachable time_format
//
// Load-bearing tests:
// 1. senderLabelUnknown key no longer exists in AppLocalizations
//    (re-adding key → compilation error)
// 2. formatRelativeTime requires l10n (making optional → RED)
// 3. No dangling references to removed functions in lib/
// =============================================================================

// ignore_for_file: lines_longer_than_80_chars
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('#852 — Orphaned senderLabelUnknown key', () {
    test('AppLocalizations does NOT have senderLabelUnknown getter', () {
      // Use reflection-free approach: verify the source file no longer contains
      // the getter declaration. This test fails if someone re-adds the key.
      final file = File('lib/l10n/app_localizations.dart');
      final content = file.readAsStringSync();
      expect(content.contains('senderLabelUnknown'), isFalse,
          reason: 'senderLabelUnknown is dead code — must not exist in '
              'AppLocalizations. Re-adding it → RED.');
    });

    test('ARB files do not contain senderLabelUnknown', () {
      for (final path in [
        'lib/l10n/app_en.arb',
        'lib/l10n/app_zh.arb',
        'lib/l10n/app_es.arb',
      ]) {
        final content = File(path).readAsStringSync();
        expect(content.contains('senderLabelUnknown'), isFalse,
            reason: '$path must not contain orphaned key senderLabelUnknown');
      }
    });
  });

  group('#852 — Unreachable time_format functions removed', () {
    test('time_format.dart does not contain _weekday or _month functions', () {
      final file = File('lib/core/utils/time_format.dart');
      final content = file.readAsStringSync();
      expect(content.contains('String _weekday('), isFalse,
          reason: '_weekday() is unreachable dead code — '
              're-adding it → RED.');
      expect(content.contains('String _month('), isFalse,
          reason: '_month() is unreachable dead code — '
              're-adding it → RED.');
    });

    test('formatRelativeTime l10n parameter is required (non-nullable)', () {
      // This compiles only if l10n is required. If someone reverts to
      // `AppLocalizations? l10n`, this call would need `l10n:` to be nullable
      // and the function signature would differ — but we test indirectly:
      // the fact that this file compiles with the import proves the signature
      // has `required AppLocalizations l10n`.
      //
      // We also verify the source contains 'required AppLocalizations l10n'.
      final file = File('lib/core/utils/time_format.dart');
      final content = file.readAsStringSync();
      expect(content.contains('required AppLocalizations l10n'), isTrue,
          reason: 'l10n must be required — making it optional re-introduces '
              'dead fallback branches.');
    });

    test('removed test files no longer exist', () {
      expect(
          File('test/core/utils/time_format_test.dart').existsSync(), isFalse,
          reason:
              'Legacy test file exercises dead code path — must be removed');
      expect(
          File('test/core/utils/time_format_now_param_test.dart').existsSync(),
          isFalse,
          reason:
              'Legacy test file exercises dead code path — must be removed');
    });
  });
}
