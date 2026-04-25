import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';

const _loginPath = '/auth/login';
const _registerPath = '/auth/register';
const _forgotPasswordPath = '/auth/forgot-password';
const _mePath = '/auth/me';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiAuthRepository(appDioClient: appDioClient);
});

class _ApiAuthRepository implements AuthRepository {
  const _ApiAuthRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _appDioClient.post<Object?>(
        _loginPath,
        data: {'email': email, 'password': password},
      );
      return _parseAuthResult(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Login failed.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _appDioClient.post<Object?>(
        _registerPath,
        data: {'email': email, 'password': password, 'name': name},
      );
      return _parseAuthResult(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Registration failed.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<AuthUser> getMe() async {
    try {
      final response = await _appDioClient.get<Object?>(_mePath);
      return _parseAuthUser(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to fetch user profile.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _appDioClient.post<Object?>(
        _forgotPasswordPath,
        data: {'email': email},
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Password reset request failed.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  AuthResult _parseAuthResult(Object? payload) {
    if (payload is! Map) {
      throw const SerializationFailure(
        message: 'Malformed auth response: expected an object.',
        causeType: 'ParseError',
      );
    }
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload);
    final accessToken = map['accessToken'];
    final refreshToken = map['refreshToken'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const SerializationFailure(
        message: 'Malformed auth response: missing accessToken.',
        causeType: 'ParseError',
      );
    }
    if (refreshToken is! String || refreshToken.isEmpty) {
      throw const SerializationFailure(
        message: 'Malformed auth response: missing refreshToken.',
        causeType: 'ParseError',
      );
    }
    return AuthResult(accessToken: accessToken, refreshToken: refreshToken);
  }

  AuthUser _parseAuthUser(Object? payload) {
    if (payload is! Map) {
      throw const SerializationFailure(
        message: 'Malformed user response: expected an object.',
        causeType: 'ParseError',
      );
    }
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload);
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      throw const SerializationFailure(
        message: 'Malformed user response: missing id.',
        causeType: 'ParseError',
      );
    }
    final name = map['name'];
    return AuthUser(
      id: id,
      name: name is String && name.isNotEmpty ? name : null,
    );
  }
}
