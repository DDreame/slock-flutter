import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';

void main() {
  late _FakeDioClient fakeDio;
  late ProviderContainer container;

  setUp(() {
    fakeDio = _FakeDioClient();
    container = ProviderContainer(
      overrides: [
        appDioClientProvider.overrideWithValue(fakeDio),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  AuthRepository repo() => container.read(authRepositoryProvider);

  group('login', () {
    test('returns AuthResult on valid response', () async {
      fakeDio.nextResponse = {
        'token': 'jwt-abc',
        'userId': 'user-1',
        'displayName': 'Alice',
      };

      final result = await repo().login(
        email: 'alice@example.com',
        password: 'secret',
      );

      expect(result.token, 'jwt-abc');
      expect(result.userId, 'user-1');
      expect(result.displayName, 'Alice');
      expect(fakeDio.lastPath, '/auth/login');
      expect(fakeDio.lastData, {
        'email': 'alice@example.com',
        'password': 'secret',
      });
    });

    test('displayName is null when missing from response', () async {
      fakeDio.nextResponse = {
        'token': 'jwt-abc',
        'userId': 'user-1',
      };

      final result = await repo().login(
        email: 'alice@example.com',
        password: 'secret',
      );

      expect(result.displayName, isNull);
    });

    test('throws SerializationFailure when token is missing', () async {
      fakeDio.nextResponse = {'userId': 'user-1'};

      expect(
        () => repo().login(email: 'a@b.com', password: 'p'),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws SerializationFailure when userId is missing', () async {
      fakeDio.nextResponse = {'token': 'jwt'};

      expect(
        () => repo().login(email: 'a@b.com', password: 'p'),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws SerializationFailure on non-map response', () async {
      fakeDio.nextResponse = 'not a map';

      expect(
        () => repo().login(email: 'a@b.com', password: 'p'),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('rethrows AppFailure from network layer', () async {
      fakeDio.nextError = const ServerFailure(
        message: 'Bad credentials',
        statusCode: 401,
      );

      expect(
        () => repo().login(email: 'a@b.com', password: 'p'),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('wraps unknown error in UnknownFailure', () async {
      fakeDio.nextError = Exception('network down');

      expect(
        () => repo().login(email: 'a@b.com', password: 'p'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('register', () {
    test('returns AuthResult on valid response', () async {
      fakeDio.nextResponse = {
        'token': 'jwt-reg',
        'userId': 'user-2',
        'displayName': 'Bob',
      };

      final result = await repo().register(
        email: 'bob@example.com',
        password: 'secret',
        displayName: 'Bob',
      );

      expect(result.token, 'jwt-reg');
      expect(result.userId, 'user-2');
      expect(result.displayName, 'Bob');
      expect(fakeDio.lastPath, '/auth/register');
      expect(fakeDio.lastData, {
        'email': 'bob@example.com',
        'password': 'secret',
        'displayName': 'Bob',
      });
    });

    test('throws SerializationFailure when token is empty', () async {
      fakeDio.nextResponse = {'token': '', 'userId': 'user-2'};

      expect(
        () => repo().register(
          email: 'a@b.com',
          password: 'p',
          displayName: 'X',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });
  });

  group('requestPasswordReset', () {
    test('sends request to correct endpoint', () async {
      fakeDio.nextResponse = null;

      await repo().requestPasswordReset(email: 'alice@example.com');

      expect(fakeDio.lastPath, '/auth/forgot-password');
      expect(fakeDio.lastData, {'email': 'alice@example.com'});
    });

    test('rethrows AppFailure', () async {
      fakeDio.nextError = const ServerFailure(
        message: 'Not found',
        statusCode: 404,
      );

      expect(
        () => repo().requestPasswordReset(email: 'a@b.com'),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('wraps unknown error in UnknownFailure', () async {
      fakeDio.nextError = Exception('timeout');

      expect(
        () => repo().requestPasswordReset(email: 'a@b.com'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });
}

class _FakeDioClient implements AppDioClient {
  Object? nextResponse;
  Object? nextError;
  String? lastPath;
  Object? lastData;

  @override
  Dio get rawDio => throw UnimplementedError();

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    lastPath = path;
    lastData = data;
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    final resp = nextResponse;
    nextResponse = null;
    return Response<T>(
      data: resp as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    throw UnimplementedError();
  }
}
