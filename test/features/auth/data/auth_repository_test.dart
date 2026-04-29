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
    test('returns AuthResult with accessToken and refreshToken', () async {
      fakeDio.nextResponse = {
        'accessToken': 'at-123',
        'refreshToken': 'rt-456',
      };

      final result = await repo().login(
        email: 'alice@example.com',
        password: 'secret',
      );

      expect(result.accessToken, 'at-123');
      expect(result.refreshToken, 'rt-456');
      expect(fakeDio.lastMethod, 'POST');
      expect(fakeDio.lastPath, '/auth/login');
      expect(fakeDio.lastData, {
        'email': 'alice@example.com',
        'password': 'secret',
      });
    });

    test('throws SerializationFailure when accessToken is missing', () async {
      fakeDio.nextResponse = {'refreshToken': 'rt-456'};

      expect(
        () => repo().login(email: 'a@b.com', password: 'p'),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws SerializationFailure when refreshToken is missing', () async {
      fakeDio.nextResponse = {'accessToken': 'at-123'};

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
    test('returns AuthResult and sends name field', () async {
      fakeDio.nextResponse = {
        'accessToken': 'at-reg',
        'refreshToken': 'rt-reg',
      };

      final result = await repo().register(
        email: 'bob@example.com',
        password: 'secret',
        name: 'Bob',
      );

      expect(result.accessToken, 'at-reg');
      expect(result.refreshToken, 'rt-reg');
      expect(fakeDio.lastPath, '/auth/register');
      expect(fakeDio.lastData, {
        'email': 'bob@example.com',
        'password': 'secret',
        'name': 'Bob',
      });
    });

    test('throws SerializationFailure when accessToken is empty', () async {
      fakeDio.nextResponse = {'accessToken': '', 'refreshToken': 'rt'};

      expect(
        () => repo().register(
          email: 'a@b.com',
          password: 'p',
          name: 'X',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });
  });

  group('getMe', () {
    test('returns AuthUser with id and name', () async {
      fakeDio.nextResponse = {
        'id': 'user-1',
        'email': 'alice@example.com',
        'name': 'Alice',
        'emailVerified': true,
        'avatar': 'https://example.com/avatar.png',
      };

      final user = await repo().getMe();

      expect(user.id, 'user-1');
      expect(user.name, 'Alice');
      expect(user.emailVerified, isTrue);
      expect(fakeDio.lastMethod, 'GET');
      expect(fakeDio.lastPath, '/auth/me');
    });

    test('name is null when missing from response', () async {
      fakeDio.nextResponse = {'id': 'user-1'};

      final user = await repo().getMe();

      expect(user.id, 'user-1');
      expect(user.name, isNull);
    });

    test('throws SerializationFailure when id is missing', () async {
      fakeDio.nextResponse = {'name': 'Alice'};

      expect(
        () => repo().getMe(),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('rethrows AppFailure from network layer', () async {
      fakeDio.nextError = const ServerFailure(
        message: 'Unauthorized',
        statusCode: 401,
      );

      expect(
        () => repo().getMe(),
        throwsA(isA<ServerFailure>()),
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

  group('resetPassword', () {
    test('posts token and password to reset endpoint', () async {
      fakeDio.nextResponse = null;

      await repo().resetPassword(token: 'reset-token', password: 'new-secret');

      expect(fakeDio.lastMethod, 'POST');
      expect(fakeDio.lastPath, '/auth/reset-password');
      expect(fakeDio.lastData, {
        'token': 'reset-token',
        'password': 'new-secret',
      });
    });
  });

  group('verifyEmail', () {
    test('posts token to verification endpoint', () async {
      fakeDio.nextResponse = null;

      await repo().verifyEmail(token: 'verify-token');

      expect(fakeDio.lastMethod, 'POST');
      expect(fakeDio.lastPath, '/auth/verify-email');
      expect(fakeDio.lastData, {'token': 'verify-token'});
    });
  });

  group('resendVerification', () {
    test('posts to resend verification endpoint', () async {
      fakeDio.nextResponse = null;

      await repo().resendVerification();

      expect(fakeDio.lastMethod, 'POST');
      expect(fakeDio.lastPath, '/auth/resend-verification');
      expect(fakeDio.lastData, isNull);
    });
  });
}

class _FakeDioClient implements AppDioClient {
  Object? nextResponse;
  Object? nextError;
  String? lastPath;
  String? lastMethod;
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
    lastPath = path;
    lastMethod = method;
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
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    return request<T>(path, method: 'POST', data: data);
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    return request<T>(path, method: 'GET');
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    return request<T>(path, method: 'DELETE', data: data);
  }
}
