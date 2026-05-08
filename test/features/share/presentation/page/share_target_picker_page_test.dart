import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';

void main() {
  final testServerId = ServerScopeId.fromRouteParam('test-server');

  HomeListState buildSuccessState({
    List<HomeChannelSummary> channels = const [],
    List<HomeDirectMessageSummary> directMessages = const [],
  }) {
    return HomeListState(
      serverScopeId: testServerId,
      status: HomeListStatus.success,
      channels: channels,
      directMessages: directMessages,
    );
  }

  Widget buildApp({
    required HomeListState homeState,
    SharedContent? sharedContent,
    ValueChanged<ShareTarget>? onTargetSelected,
    VoidCallback? onCancel,
  }) {
    return ProviderScope(
      overrides: [
        homeListStoreProvider.overrideWith(() {
          return _FixedHomeListStore(homeState);
        }),
        shareIntentStoreProvider.overrideWith(() {
          return _FixedShareIntentStore(sharedContent);
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: ShareTargetPickerPage(
          onTargetSelected: onTargetSelected ?? (_) {},
          onCancel: onCancel ?? () {},
        ),
      ),
    );
  }

  group('ShareTargetPickerPage', () {
    testWidgets('shows app bar title', (tester) async {
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share to...'), findsOneWidget);
    });

    testWidgets('shows cancel button', (tester) async {
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('cancel button calls onCancel', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        buildApp(
          homeState: buildSuccessState(),
          onCancel: () => cancelled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      expect(cancelled, isTrue);
    });

    testWidgets('shows channels section header', (tester) async {
      final channels = [
        HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: testServerId, value: 'ch-1'),
          name: 'general',
        ),
      ];
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState(channels: channels)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Channels'), findsOneWidget);
    });

    testWidgets('shows channel names', (tester) async {
      final channels = [
        HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: testServerId, value: 'ch-1'),
          name: 'general',
        ),
        HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: testServerId, value: 'ch-2'),
          name: 'random',
        ),
      ];
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState(channels: channels)),
      );
      await tester.pumpAndSettle();

      expect(find.text('# general'), findsOneWidget);
      expect(find.text('# random'), findsOneWidget);
    });

    testWidgets('shows DMs section header', (tester) async {
      final dms = [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(serverId: testServerId, value: 'dm-1'),
          title: 'Alice',
        ),
      ];
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState(directMessages: dms)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Direct Messages'), findsOneWidget);
    });

    testWidgets('shows DM names', (tester) async {
      final dms = [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(serverId: testServerId, value: 'dm-1'),
          title: 'Alice',
        ),
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(serverId: testServerId, value: 'dm-2'),
          title: 'Bob',
        ),
      ];
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState(directMessages: dms)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('tapping channel calls onTargetSelected with channel target',
        (tester) async {
      ShareTarget? selected;
      final channels = [
        HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: testServerId, value: 'ch-1'),
          name: 'general',
        ),
      ];
      await tester.pumpWidget(
        buildApp(
          homeState: buildSuccessState(channels: channels),
          onTargetSelected: (target) => selected = target,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('# general'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.isChannel, isTrue);
      expect(selected!.scopeId, 'ch-1');
    });

    testWidgets('tapping DM calls onTargetSelected with DM target',
        (tester) async {
      ShareTarget? selected;
      final dms = [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(serverId: testServerId, value: 'dm-1'),
          title: 'Alice',
        ),
      ];
      await tester.pumpWidget(
        buildApp(
          homeState: buildSuccessState(directMessages: dms),
          onTargetSelected: (target) => selected = target,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.isChannel, isFalse);
      expect(selected!.scopeId, 'dm-1');
    });

    testWidgets('shows preview card when shared content exists',
        (tester) async {
      const sharedContent = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'Shared text'),
      ]);
      await tester.pumpWidget(
        buildApp(
          homeState: buildSuccessState(),
          sharedContent: sharedContent,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared text'), findsOneWidget);
    });

    testWidgets('shows loading when home list is loading', (tester) async {
      await tester.pumpWidget(
        buildApp(
          homeState: HomeListState(
            serverScopeId: testServerId,
            status: HomeListStatus.loading,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides channels section when no channels', (tester) async {
      final dms = [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(serverId: testServerId, value: 'dm-1'),
          title: 'Alice',
        ),
      ];
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState(directMessages: dms)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Channels'), findsNothing);
      expect(find.text('Direct Messages'), findsOneWidget);
    });

    testWidgets('hides DMs section when no DMs', (tester) async {
      final channels = [
        HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: testServerId, value: 'ch-1'),
          name: 'general',
        ),
      ];
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState(channels: channels)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('Direct Messages'), findsNothing);
    });

    testWidgets('shows search field', (tester) async {
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('search filters channels', (tester) async {
      final channels = [
        HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: testServerId, value: 'ch-1'),
          name: 'general',
        ),
        HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: testServerId, value: 'ch-2'),
          name: 'random',
        ),
      ];
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState(channels: channels)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'gen');
      await tester.pump();

      expect(find.text('# general'), findsOneWidget);
      expect(find.text('# random'), findsNothing);
    });

    testWidgets('search filters DMs', (tester) async {
      final dms = [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(serverId: testServerId, value: 'dm-1'),
          title: 'Alice',
        ),
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(serverId: testServerId, value: 'dm-2'),
          title: 'Bob',
        ),
      ];
      await tester.pumpWidget(
        buildApp(homeState: buildSuccessState(directMessages: dms)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ali');
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
    });
  });
}

/// Fixed [HomeListStore] that returns a pre-defined state.
class _FixedHomeListStore extends HomeListStore {
  _FixedHomeListStore(this._fixedState);
  final HomeListState _fixedState;

  @override
  HomeListState build() => _fixedState;
}

/// Fixed [ShareIntentStore] that returns a pre-defined state.
class _FixedShareIntentStore extends ShareIntentStore {
  _FixedShareIntentStore(this._fixedState);
  final SharedContent? _fixedState;

  @override
  SharedContent? build() => _fixedState;
}
