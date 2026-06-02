import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/features/home/application/conversation_swipe_preference.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  test('defaults to left archive and right pin', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final state = container.read(conversationSwipePreferenceProvider);
    expect(state.left, ConversationSwipeAction.archive);
    expect(state.right, ConversationSwipeAction.togglePin);
  });

  test('persists configured actions including none', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier =
        container.read(conversationSwipePreferenceProvider.notifier);
    notifier.setLeftAction(ConversationSwipeAction.toggleMute);
    notifier.setRightAction(ConversationSwipeAction.none);

    expect(
      prefs.getString(ConversationSwipePreference.leftPrefsKey),
      ConversationSwipeAction.toggleMute.name,
    );
    expect(
      prefs.getString(ConversationSwipePreference.rightPrefsKey),
      ConversationSwipeAction.none.name,
    );

    final restoredContainer = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restoredContainer.dispose);

    final restored =
        restoredContainer.read(conversationSwipePreferenceProvider);
    expect(restored.left, ConversationSwipeAction.toggleMute);
    expect(restored.right, ConversationSwipeAction.none);
  });
}
