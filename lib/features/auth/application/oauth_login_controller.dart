import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/session/session_store.dart';

final oauthLoginControllerProvider =
    AutoDisposeAsyncNotifierProvider<OAuthLoginController, void>(
  OAuthLoginController.new,
);

class OAuthLoginController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String providerId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(sessionStoreProvider.notifier).loginWithOAuth(
            providerId: providerId,
          );
    });
  }
}
