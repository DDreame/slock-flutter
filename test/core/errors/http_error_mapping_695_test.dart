// ignore_for_file: prefer_const_constructors

// =============================================================================
// #695 — HTTP error mapping (408/409/422) + Drift migration + serverId invariant
//
// Tests:
// 1. AppFailureMapper maps 408 → TimeoutFailure, 409 → ConflictFailure,
//    422 → ValidationFailure.
// 2. AppDatabase migration strategy scaffold (version 1→same doesn't crash).
// 3. isRetryable returns correct values for new failure types.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/local_data/app_database.dart';
import 'package:slock_app/core/network/app_failure_mapper.dart';

void main() {
  group('#695 — HTTP error mapping (408/409/422)', () {
    const mapper = AppFailureMapper();

    DioException buildBadResponse(int statusCode) {
      final requestOptions = RequestOptions(path: '/test');
      return DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: statusCode,
          headers: Headers.fromMap({
            'x-request-id': ['req-$statusCode'],
          }),
        ),
      );
    }

    test('408 → TimeoutFailure', () {
      final failure = mapper.map(buildBadResponse(408));

      expect(failure, isA<TimeoutFailure>());
      expect(failure.statusCode, 408);
      expect(failure.requestId, 'req-408');
      expect(failure.isRetryable, isTrue);
    });

    test('409 → ConflictFailure', () {
      final failure = mapper.map(buildBadResponse(409));

      expect(failure, isA<ConflictFailure>());
      expect(failure.statusCode, 409);
      expect(failure.requestId, 'req-409');
      expect(failure.isRetryable, isFalse);
    });

    test('422 → ValidationFailure', () {
      final failure = mapper.map(buildBadResponse(422));

      expect(failure, isA<ValidationFailure>());
      expect(failure.statusCode, 422);
      expect(failure.requestId, 'req-422');
      expect(failure.isRetryable, isFalse);
    });

    test('existing mappings still work (regression)', () {
      expect(mapper.map(buildBadResponse(401)), isA<UnauthorizedFailure>());
      expect(mapper.map(buildBadResponse(403)), isA<ForbiddenFailure>());
      expect(mapper.map(buildBadResponse(404)), isA<NotFoundFailure>());
      expect(mapper.map(buildBadResponse(429)), isA<RateLimitFailure>());
      expect(mapper.map(buildBadResponse(500)), isA<ServerFailure>());
      expect(mapper.map(buildBadResponse(503)), isA<ServerFailure>());
    });

    test('unrecognized 4xx still returns UnknownFailure', () {
      expect(mapper.map(buildBadResponse(418)), isA<UnknownFailure>());
      expect(mapper.map(buildBadResponse(451)), isA<UnknownFailure>());
    });
  });

  group('#695 — Drift migration strategy', () {
    test('AppDatabase opens at schema version 1 without crash', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Simply opening the database executes onCreate. If the migration
      // strategy is misconfigured, this would throw.
      final summaries = await db.conversationLocalDao
          .listConversationSummaries('server-1', surface: 'channel');
      expect(summaries, isEmpty);
    });

    test('migration strategy exists and is of correct type', () {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Verify migration getter doesn't throw.
      expect(db.migration, isA<MigrationStrategy>());
    });
  });

  group('#695 — ConflictFailure / ValidationFailure properties', () {
    test('ConflictFailure is not retryable', () {
      const failure = ConflictFailure(statusCode: 409);
      expect(failure.isRetryable, isFalse);
    });

    test('ValidationFailure is not retryable', () {
      const failure = ValidationFailure(statusCode: 422);
      expect(failure.isRetryable, isFalse);
    });

    test('ConflictFailure toString contains type info', () {
      const failure = ConflictFailure(
        statusCode: 409,
        message: 'Resource already exists',
      );
      expect(failure.toString(), contains('ConflictFailure'));
      expect(failure.toString(), contains('409'));
    });

    test('ValidationFailure toString contains type info', () {
      const failure = ValidationFailure(
        statusCode: 422,
        message: 'Invalid email format',
      );
      expect(failure.toString(), contains('ValidationFailure'));
      expect(failure.toString(), contains('422'));
    });
  });
}
