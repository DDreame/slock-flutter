import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/session/session_store.dart';

final verifyEmailControllerProvider =
    AutoDisposeAsyncNotifierProvider<VerifyEmailController, void>(
  VerifyEmailController.new,
);

class VerifyEmailController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submitToken(String token) async {
    state = const AsyncLoading();
    try {
      await ref.read(sessionStoreProvider.notifier).verifyEmail(token: token);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> resendVerification() async {
    state = const AsyncLoading();
    try {
      await ref.read(sessionStoreProvider.notifier).resendVerification();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
