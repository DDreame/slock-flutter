// =============================================================================
// Scan #51 P1 — Load-bearing test: BrowseChannelsPage._loadChannels generic
// catch.
//
// Proves: A non-AppFailure exception from loadAvailableChannels renders error
// state (not stuck loading). Reverting the generic `catch (_)` → this test
// fails (CircularProgressIndicator stays visible forever).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/available_channel.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/browse_channels_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  group('BrowseChannelsPage — generic catch', () {
    testWidgets('non-AppFailure exception shows error state, not stuck loading',
        (tester) async {
      final repo = _ThrowingChannelManagementRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelManagementRepositoryProvider.overrideWithValue(repo),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('srv-1')),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const BrowseChannelsPage(),
          ),
        ),
      );

      // Initially shows loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let the async _loadChannels() complete
      await tester.pumpAndSettle();

      // Should show error state (retry button), NOT stuck in loading
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('AppFailure still surfaces correctly', (tester) async {
      final repo = _AppFailureChannelManagementRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelManagementRepositoryProvider.overrideWithValue(repo),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('srv-1')),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const BrowseChannelsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Error state with retry
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Throws a non-AppFailure exception to test the generic catch path.
class _ThrowingChannelManagementRepository
    implements ChannelManagementRepository {
  @override
  Future<List<AvailableChannel>> loadAvailableChannels(
    ServerScopeId serverId,
  ) async {
    throw StateError('Unexpected non-AppFailure error');
  }

  @override
  Future<String> createChannel(
    ServerScopeId serverId, {
    required String name,
    String? description,
    bool? isPrivate,
  }) async =>
      '';

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
  Future<void> archiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> unarchiveChannel(
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
}

/// Throws an AppFailure to test the typed catch path still works.
class _AppFailureChannelManagementRepository
    extends _ThrowingChannelManagementRepository {
  @override
  Future<List<AvailableChannel>> loadAvailableChannels(
    ServerScopeId serverId,
  ) async {
    throw const NotFoundFailure();
  }
}
