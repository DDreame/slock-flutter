import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/session/session_state.dart';

final sessionStoreProvider = NotifierProvider<SessionStore, SessionState>(
  SessionStore.new,
);

class SessionStore extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  Future<void> restoreSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      userId: 'stub-user-id',
      displayName: email.split('@').first,
      token: 'stub-token',
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      userId: 'stub-user-id',
      displayName: displayName,
      token: 'stub-token',
    );
  }

  Future<void> requestPasswordReset({required String email}) async {}

  void logout() {
    state = const SessionState(status: AuthStatus.unauthenticated);
  }
}
