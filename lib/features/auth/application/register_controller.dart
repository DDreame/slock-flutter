import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/session/session_store.dart';

final registerControllerProvider =
    AutoDisposeAsyncNotifierProvider<RegisterController, void>(
  RegisterController.new,
);

class RegisterController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(sessionStoreProvider.notifier)
          .register(email: email, password: password, displayName: displayName);
    });
  }
}
