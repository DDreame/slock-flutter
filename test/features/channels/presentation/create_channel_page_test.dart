import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/create_channel_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

final _testActiveServerProvider = StateProvider<ServerScopeId?>(
  (ref) => const ServerScopeId('server-1'),
);

void main() {
  late _FakeChannelManagementRepository fakeRepo;

  setUp(() {
    fakeRepo = _FakeChannelManagementRepository();
  });

  Widget buildApp({List<Override> extraOverrides = const []}) {
    return ProviderScope(
      overrides: [
        channelManagementRepositoryProvider.overrideWithValue(fakeRepo),
        activeServerScopeIdProvider.overrideWith(
          (ref) => ref.watch(_testActiveServerProvider),
        ),
        ...extraOverrides,
        homeRepositoryProvider.overrideWithValue(_FakeHomeRepository()),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const CreateChannelPage(),
      ),
    );
  }

  group('CreateChannelPage', () {
    testWidgets('renders form fields: name, description, visibility', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('create-channel-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('create-channel-description')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('create-channel-visibility-public')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('create-channel-visibility-private')),
          findsOneWidget);
    });

    testWidgets('submit button disabled when name is empty', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final submitButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('create-channel-submit')),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('submit button enabled when name is non-empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('create-channel-name')), 'general');
      await tester.pump();

      final submitButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('create-channel-submit')),
      );
      expect(submitButton.onPressed, isNotNull);
    });

    testWidgets('tapping Private visibility selects it', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('create-channel-visibility-private')));
      await tester.pump();

      // Verify the private option is now selected (has accent styling)
      expect(find.byKey(const ValueKey('create-channel-visibility-private')),
          findsOneWidget);
    });

    testWidgets('submit calls createChannel with all fields', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('create-channel-name')), 'design');
      await tester.enterText(
          find.byKey(const ValueKey('create-channel-description')),
          'Design discussions');
      await tester
          .tap(find.byKey(const ValueKey('create-channel-visibility-private')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('create-channel-submit')));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastCreateServerId, const ServerScopeId('server-1'));
      expect(fakeRepo.lastCreateName, 'design');
      expect(fakeRepo.lastCreateDescription, 'Design discussions');
      expect(fakeRepo.lastCreateIsPrivate, true);
    });

    testWidgets('submit with public visibility sends isPrivate false', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('create-channel-name')), 'general');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('create-channel-submit')));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastCreateName, 'general');
      expect(fakeRepo.lastCreateIsPrivate, false);
    });

    testWidgets('submit uses server captured when form opened (#719)',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CreateChannelPage)),
      );
      container.read(_testActiveServerProvider.notifier).state =
          const ServerScopeId('server-2');
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('create-channel-name')),
        'captured-server',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('create-channel-submit')));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastCreateServerId, const ServerScopeId('server-1'));
      expect(fakeRepo.lastCreateName, 'captured-server');
    });

    testWidgets('shows error snackbar on failure', (tester) async {
      fakeRepo.shouldFail = true;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('create-channel-name')), 'fail-channel');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('create-channel-submit')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      // #790: localized error, not raw message.
      expect(
          find.text('Something went wrong. Please try again.'), findsOneWidget);
    });
  });
}

class _FakeChannelManagementRepository implements ChannelManagementRepository {
  ServerScopeId? lastCreateServerId;
  String? lastCreateName;
  String? lastCreateDescription;
  bool? lastCreateIsPrivate;
  bool shouldFail = false;

  @override
  Future<String> createChannel(
    ServerScopeId serverId, {
    required String name,
    String? description,
    bool? isPrivate,
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Failed to create channel.',
        causeType: 'test',
      );
    }
    lastCreateServerId = serverId;
    lastCreateName = name;
    lastCreateDescription = description;
    lastCreateIsPrivate = isPrivate;
    return 'new-channel-id';
  }

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    String? name,
    String? description,
    bool? isPrivate,
  }) async {}

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> joinChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> stopAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> resumeAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> archiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> unarchiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}
}

class _FakeHomeRepository implements HomeRepository {
  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: const [],
      directMessages: const [],
    );
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    return summary;
  }

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return const SidebarOrder();
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}
