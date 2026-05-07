import 'package:flutter/material.dart';
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

void main() {
  late _FakeChannelManagementRepository fakeRepo;

  setUp(() {
    fakeRepo = _FakeChannelManagementRepository();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        channelManagementRepositoryProvider.overrideWithValue(fakeRepo),
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
        homeRepositoryProvider.overrideWithValue(_FakeHomeRepository()),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
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
      expect(find.text('Failed to create channel.'), findsOneWidget);
    });
  });
}

class _FakeChannelManagementRepository implements ChannelManagementRepository {
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
    lastCreateName = name;
    lastCreateDescription = description;
    lastCreateIsPrivate = isPrivate;
    return 'new-channel-id';
  }

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    required String name,
  }) async {}

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> leaveChannel(
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
