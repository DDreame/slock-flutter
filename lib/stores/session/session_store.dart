import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      if (token != null && token.isNotEmpty) {
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
          accessToken: token,
          fallbackUserId: userId,
          fallbackDisplayName: displayName,
        );
        return;
      }
    } catch (_) {
      // Storage read failure — fall through to unauthenticated.
    }
    state = const SessionState(status: AuthStatus.unauthenticated);
  }

  Future<void> login({required String email, required String password}) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email: email, password: password);

    await _storage.write(
      key: SessionStorageKeys.refreshToken,
      value: result.refreshToken,
    );
    await _hydrateAuthenticatedSession(accessToken: result.accessToken);
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

    await _storage.write(
      key: SessionStorageKeys.refreshToken,
      value: result.refreshToken,
    );
    await _hydrateAuthenticatedSession(
      accessToken: result.accessToken,
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
    required String accessToken,
    String? fallbackUserId,
    String? fallbackDisplayName,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      token: accessToken,
      userId: fallbackUserId,
      displayName: fallbackDisplayName,
    );

    final user = await _loadCurrentUser();
    state = SessionState(
      status: AuthStatus.authenticated,
      token: accessToken,
      userId: user?.id ?? fallbackUserId,
      displayName: user?.name ?? fallbackDisplayName,
      emailVerified: user?.emailVerified,
    );
    await _persistSession();
  }

  Future<AuthUser?> _loadCurrentUser() async {
    try {
      return await ref.read(authRepositoryProvider).getMe();
    } catch (e, st) {
      ref.read(crashReporterProvider).captureException(e, stackTrace: st);
      return null;
    }
  }
}
