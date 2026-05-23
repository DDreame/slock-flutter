// =============================================================================
// #790 — AppFailure.userMessage(l10n) Extension
//
// Verifies: Each AppFailure subtype maps to the correct localized string via
// the exhaustive switch in AppFailureUserMessage.userMessage().
//
// Load-bearing proof:
//   Reverting the extension (removing app_failure_user_message.dart) causes
//   a compile error at all 50+ callsites. The extension is the single source
//   of truth for user-facing error strings.
// =============================================================================

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  group('#790 — AppFailure.userMessage(l10n)', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    test('NetworkFailure maps to errorNetwork', () {
      const failure = NetworkFailure(message: 'Connection reset by peer');
      expect(failure.userMessage(l10n), l10n.errorNetwork);
      expect(failure.userMessage(l10n), isNot(contains('Connection reset')));
    });

    test('TimeoutFailure maps to errorTimeout', () {
      const failure = TimeoutFailure(message: 'DioException: timeout');
      expect(failure.userMessage(l10n), l10n.errorTimeout);
    });

    test('UnauthorizedFailure maps to errorUnauthorized', () {
      const failure = UnauthorizedFailure(message: 'Token expired');
      expect(failure.userMessage(l10n), l10n.errorUnauthorized);
    });

    test('ForbiddenFailure maps to errorForbidden', () {
      const failure = ForbiddenFailure(message: 'Insufficient permissions');
      expect(failure.userMessage(l10n), l10n.errorForbidden);
    });

    test('NotFoundFailure maps to errorNotFound', () {
      const failure = NotFoundFailure(message: '404 Not Found');
      expect(failure.userMessage(l10n), l10n.errorNotFound);
    });

    test('ConflictFailure maps to errorConflict', () {
      const failure = ConflictFailure(message: 'Version conflict');
      expect(failure.userMessage(l10n), l10n.errorConflict);
    });

    test('ValidationFailure maps to errorValidation', () {
      const failure = ValidationFailure(message: 'email: invalid format');
      expect(failure.userMessage(l10n), l10n.errorValidation);
    });

    test('RateLimitFailure maps to errorRateLimit', () {
      const failure = RateLimitFailure(message: 'rate_limit_exceeded');
      expect(failure.userMessage(l10n), l10n.errorRateLimit);
    });

    test('ServerFailure maps to errorServer', () {
      const failure = ServerFailure(message: 'Internal Server Error');
      expect(failure.userMessage(l10n), l10n.errorServer);
    });

    test('CancelledFailure maps to errorCancelled', () {
      const failure = CancelledFailure(message: 'Request cancelled');
      expect(failure.userMessage(l10n), l10n.errorCancelled);
    });

    test('SerializationFailure maps to errorUnknown', () {
      const failure = SerializationFailure(message: 'FormatException');
      expect(failure.userMessage(l10n), l10n.errorUnknown);
    });

    test('UnknownFailure maps to errorUnknown', () {
      const failure = UnknownFailure(message: 'java.lang.NullPointerException');
      expect(failure.userMessage(l10n), l10n.errorUnknown);
      expect(failure.userMessage(l10n), isNot(contains('java.lang')));
    });

    test('raw message is never exposed via userMessage', () {
      const failures = <AppFailure>[
        NetworkFailure(message: 'Connection reset by peer'),
        TimeoutFailure(message: 'DioException [receiveTimeout]'),
        ServerFailure(message: 'Internal Server Error at /api/v1/channels'),
        UnknownFailure(message: 'Unexpected token < in JSON at position 0'),
      ];
      for (final failure in failures) {
        final userMsg = failure.userMessage(l10n);
        expect(userMsg, isNot(equals(failure.message)),
            reason: '${failure.runtimeType}: raw message must not leak');
      }
    });

    test('Chinese locale returns Chinese strings', () {
      final zhL10n = lookupAppLocalizations(const Locale('zh'));
      const failure = NetworkFailure(message: 'Connection reset by peer');
      final msg = failure.userMessage(zhL10n);
      // Chinese message should contain Chinese characters.
      expect(msg, contains('网络'));
    });
  });
}
