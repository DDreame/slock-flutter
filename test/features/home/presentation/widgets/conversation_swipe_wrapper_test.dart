import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/haptic/haptic_service.dart';
import 'package:slock_app/features/home/application/conversation_swipe_preference.dart';
import 'package:slock_app/features/home/presentation/widgets/conversation_swipe_wrapper.dart';
import 'package:slock_app/features/settings/data/haptic_preference.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  Widget buildApp({
    required ConversationSwipeAction left,
    required ConversationSwipeAction right,
    VoidCallback? onArchive,
    VoidCallback? onTogglePin,
    VoidCallback? onToggleMute,
  }) {
    return ProviderScope(
      overrides: [
        hapticServiceProvider.overrideWithValue(_NoOpHapticService()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 96,
            child: ConversationSwipeWrapper(
              itemKey: 'test-row',
              actions: ConversationSwipeActions(left: left, right: right),
              callbacks: ConversationSwipeCallbacks(
                onArchive: onArchive,
                onTogglePin: onTogglePin,
                onToggleMute: onToggleMute,
              ),
              isPinned: false,
              isMuted: false,
              child: const ListTile(
                key: ValueKey('conversation-row'),
                title: Text('General'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('left swipe triggers configured archive action', (tester) async {
    var archiveCount = 0;
    await tester.pumpWidget(buildApp(
      left: ConversationSwipeAction.archive,
      right: ConversationSwipeAction.togglePin,
      onArchive: () => archiveCount++,
      onTogglePin: () {},
    ));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey('conversation-row')),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(archiveCount, 1);
    expect(find.byKey(const ValueKey('conversation-row')), findsOneWidget);
  });

  testWidgets('right swipe triggers configured pin action', (tester) async {
    var pinCount = 0;
    await tester.pumpWidget(buildApp(
      left: ConversationSwipeAction.archive,
      right: ConversationSwipeAction.togglePin,
      onArchive: () {},
      onTogglePin: () => pinCount++,
    ));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey('conversation-row')),
      const Offset(500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(pinCount, 1);
  });

  testWidgets('none disables that direction', (tester) async {
    var archiveCount = 0;
    await tester.pumpWidget(buildApp(
      left: ConversationSwipeAction.none,
      right: ConversationSwipeAction.togglePin,
      onArchive: () => archiveCount++,
      onTogglePin: () {},
    ));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey('conversation-row')),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(archiveCount, 0);
  });

  testWidgets('swipe reveal shows configured action label and icon',
      (tester) async {
    await tester.pumpWidget(buildApp(
      left: ConversationSwipeAction.toggleMute,
      right: ConversationSwipeAction.togglePin,
      onToggleMute: () {},
      onTogglePin: () {},
    ));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('conversation-row'))),
    );
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();

    expect(find.text('Mute'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);

    await gesture.up();
  });
}

/// No-op [HapticService] for tests that don't verify haptic behavior.
class _NoOpHapticService extends HapticService {
  _NoOpHapticService() : super(repo: _AlwaysMediumRepo());

  @override
  Future<void> lightImpact() async {}

  @override
  Future<void> mediumImpact() async {}

  @override
  Future<void> heavyImpact() async {}

  @override
  Future<void> selectionClick() async {}

  @override
  Future<void> successNotification() async {}

  @override
  Future<void> errorNotification() async {}
}

class _AlwaysMediumRepo implements HapticPreferenceRepository {
  @override
  HapticIntensity getIntensity() => HapticIntensity.medium;

  @override
  Future<void> setIntensity(HapticIntensity intensity) async {}
}
