import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/session/session_store.dart';

final loginControllerProvider =
    AutoDisposeAsyncNotifierProvider<LoginController, void>(
      LoginController.new,
    );

class LoginController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(sessionStoreProvider.notifier)
          .login(email: email, password: password);
    });
  }
}
