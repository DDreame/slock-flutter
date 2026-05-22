import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/stores/session/session_store.dart';

final resetPasswordControllerProvider =
    AutoDisposeAsyncNotifierProvider<ResetPasswordController, void>(
  ResetPasswordController.new,
);

class ResetPasswordController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String token,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(sessionStoreProvider.notifier).resetPassword(
            token: token,
            password: password,
          );
      state = const AsyncData(null);
    } on AppFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } catch (error, stackTrace) {
      // Non-AppFailure exceptions (e.g. TimeoutException, network errors)
      // enter failure state without rethrowing — prevents unhandled exception
      // crash (#720).
      state = AsyncError(error, stackTrace);
    }
  }
}
