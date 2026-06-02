import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

enum ConversationSwipeAction {
  none,
  archive,
  togglePin,
  toggleMute;

  static ConversationSwipeAction? fromStored(String? value) {
    if (value == null) return null;
    return ConversationSwipeAction.values.firstWhere(
      (action) => action.name == value,
      orElse: () => ConversationSwipeAction.none,
    );
  }
}

class ConversationSwipePreference {
  const ConversationSwipePreference({
    this.left = ConversationSwipeAction.archive,
    this.right = ConversationSwipeAction.togglePin,
  });

  static const leftPrefsKey = 'conversation_swipe_left_action';
  static const rightPrefsKey = 'conversation_swipe_right_action';

  final ConversationSwipeAction left;
  final ConversationSwipeAction right;

  ConversationSwipePreference copyWith({
    ConversationSwipeAction? left,
    ConversationSwipeAction? right,
  }) {
    return ConversationSwipePreference(
      left: left ?? this.left,
      right: right ?? this.right,
    );
  }
}

final conversationSwipePreferenceProvider = NotifierProvider<
    ConversationSwipePreferenceNotifier, ConversationSwipePreference>(
  ConversationSwipePreferenceNotifier.new,
);

class ConversationSwipePreferenceNotifier
    extends Notifier<ConversationSwipePreference> {
  @override
  ConversationSwipePreference build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ConversationSwipePreference(
      left: ConversationSwipeAction.fromStored(
            prefs.getString(ConversationSwipePreference.leftPrefsKey),
          ) ??
          ConversationSwipeAction.archive,
      right: ConversationSwipeAction.fromStored(
            prefs.getString(ConversationSwipePreference.rightPrefsKey),
          ) ??
          ConversationSwipeAction.togglePin,
    );
  }

  void setLeftAction(ConversationSwipeAction action) {
    state = state.copyWith(left: action);
    ref
        .read(sharedPreferencesProvider)
        .setString(ConversationSwipePreference.leftPrefsKey, action.name);
  }

  void setRightAction(ConversationSwipeAction action) {
    state = state.copyWith(right: action);
    ref
        .read(sharedPreferencesProvider)
        .setString(ConversationSwipePreference.rightPrefsKey, action.name);
  }
}
