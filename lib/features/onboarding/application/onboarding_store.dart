import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

class OnboardingState {
  const OnboardingState({this.isComplete = false});

  final bool isComplete;

  OnboardingState copyWith({bool? isComplete}) {
    return OnboardingState(
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

abstract class OnboardingRepository {
  const OnboardingRepository();

  static const completeKey = 'onboardingComplete';

  bool isComplete();

  Future<void> setComplete();
}

class SharedPrefsOnboardingRepository extends OnboardingRepository {
  const SharedPrefsOnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool isComplete() =>
      _prefs.getBool(OnboardingRepository.completeKey) ?? false;

  @override
  Future<void> setComplete() =>
      _prefs.setBool(OnboardingRepository.completeKey, true);
}

class _StartupMissingOnboardingRepository extends OnboardingRepository {
  const _StartupMissingOnboardingRepository();

  @override
  bool isComplete() => true;

  @override
  Future<void> setComplete() async {}
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  try {
    return SharedPrefsOnboardingRepository(
        ref.watch(sharedPreferencesProvider));
  } on UnimplementedError {
    return const _StartupMissingOnboardingRepository();
  }
});

final onboardingStoreProvider =
    NotifierProvider<OnboardingStore, OnboardingState>(OnboardingStore.new);

class OnboardingStore extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    return OnboardingState(
      isComplete: ref.read(onboardingRepositoryProvider).isComplete(),
    );
  }

  Future<void> complete() async {
    await ref.read(onboardingRepositoryProvider).setComplete();
    state = state.copyWith(isComplete: true);
  }
}
