import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_state.dart';

final sessionStoreProvider = NotifierProvider<SessionStore, SessionState>(
  SessionStore.new,
);

class SessionStore extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  SecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> restoreSession() async {
    try {
      final token = await _storage.read(key: SessionStorageKeys.token);
      final refreshToken =
          await _storage.read(key: SessionStorageKeys.refreshToken);

      // Require both tokens for a valid session. If only one is present the
      // pair is incomplete and cannot recover from a 401, so clear it out.
      if (token != null && token.isNotEmpty) {
        if (refreshToken == null || refreshToken.isEmpty) {
          await SessionStorageKeys.clear(_storage);
          state = const SessionState(status: AuthStatus.unauthenticated);
          return;
        }

        final userId = await _storage.read(key: SessionStorageKeys.userId);
        final displayName =
            await _storage.read(key: SessionStorageKeys.displayName);
        state = SessionState(
          status: AuthStatus.authenticated,
          token: token,
          userId: userId,
          displayName: displayName,
        );
        await _hydrateAuthenticatedSession(
          fallbackUserId: userId,
          fallbackDisplayName: displayName,
        );
        return;
      }

      // Only refresh token present — incomplete pair.
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await SessionStorageKeys.clear(_storage);
      }
    } catch (_) {
      // Storage read failure — fall through to unauthenticated.
    }
    state = const SessionState(status: AuthStatus.unauthenticated);
  }

  Future<void> login({required String email, required String password}) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email: email, password: password);

    state = state.copyWith(
      status: AuthStatus.authenticated,
      token: result.accessToken,
    );
    await _storage.write(
      key: SessionStorageKeys.refreshToken,
      value: result.refreshToken,
    );
    await _hydrateAuthenticatedSession();
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.register(
      email: email,
      password: password,
      name: displayName,
    );

    state = state.copyWith(
      status: AuthStatus.authenticated,
      token: result.accessToken,
    );
    await _storage.write(
      key: SessionStorageKeys.refreshToken,
      value: result.refreshToken,
    );
    await _hydrateAuthenticatedSession(
      fallbackDisplayName: displayName,
    );
  }

  Future<void> requestPasswordReset({required String email}) async {
    await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await ref.read(authRepositoryProvider).resetPassword(
          token: token,
          password: password,
        );
  }

  Future<void> verifyEmail({required String token}) async {
    await ref.read(authRepositoryProvider).verifyEmail(token: token);

    if (!state.isAuthenticated) {
      return;
    }

    final user = await _loadCurrentUser();
    state = state.copyWith(
      userId: user?.id,
      displayName: user?.name,
      emailVerified: user?.emailVerified ?? true,
    );
    await _persistSession();
  }

  Future<void> resendVerification() async {
    await ref.read(authRepositoryProvider).resendVerification();
  }

  Future<void> logout() async {
    await ref.read(serverSelectionStoreProvider.notifier).clearSelection();
    await SessionStorageKeys.clear(_storage);
    state = const SessionState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    state = state.copyWith(token: accessToken);
    await _storage.write(key: SessionStorageKeys.token, value: accessToken);
    await _storage.write(
      key: SessionStorageKeys.refreshToken,
      value: refreshToken,
    );
  }

  Future<void> _persistSession() async {
    final s = state;
    if (s.token != null) {
      await _storage.write(key: SessionStorageKeys.token, value: s.token!);
    }
    if (s.userId != null) {
      await _storage.write(key: SessionStorageKeys.userId, value: s.userId!);
    }
    if (s.displayName != null) {
      await _storage.write(
        key: SessionStorageKeys.displayName,
        value: s.displayName!,
      );
    }
  }

  Future<void> _hydrateAuthenticatedSession({
    String? fallbackUserId,
    String? fallbackDisplayName,
  }) async {
    try {
      final user = await _loadCurrentUser();

      // Use state.token — it may have been refreshed by updateTokens()
      // during the getMe() call (Dio interceptor 401 retry). Never use a
      // stale parameter value that could clobber a fresh token.
      state = SessionState(
        status: AuthStatus.authenticated,
        token: state.token,
        userId: user?.id ?? fallbackUserId,
        displayName: user?.name ?? fallbackDisplayName,
        emailVerified: user?.emailVerified,
      );
      await _persistSession();
    } on UnauthorizedFailure {
      await logout();
    } on ForbiddenFailure {
      await logout();
    }
  }

  Future<AuthUser?> _loadCurrentUser() async {
    try {
      return await ref.read(authRepositoryProvider).getMe();
    } on UnauthorizedFailure {
      rethrow;
    } on ForbiddenFailure {
      rethrow;
    } catch (e, st) {
      ref.read(crashReporterProvider).captureException(e, stackTrace: st);
      return null;
    }
  }
}
