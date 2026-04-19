import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/session/session_store.dart';

final forgotPasswordControllerProvider =
    AutoDisposeAsyncNotifierProvider<ForgotPasswordController, void>(
      ForgotPasswordController.new,
    );

class ForgotPasswordController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String email}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(sessionStoreProvider.notifier)
          .requestPasswordReset(email: email);
    });
  }
}
