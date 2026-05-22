import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/features/onboarding/application/onboarding_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  test('defaults incomplete and persists completion flag', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(onboardingStoreProvider).isComplete, isFalse);

    await container.read(onboardingStoreProvider.notifier).complete();

    expect(container.read(onboardingStoreProvider).isComplete, isTrue);
    expect(prefs.getBool(OnboardingRepository.completeKey), isTrue);
  });

  test('restores existing completion flag', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingRepository.completeKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(onboardingStoreProvider).isComplete, isTrue);
  });
}
