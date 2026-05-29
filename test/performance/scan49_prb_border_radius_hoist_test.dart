// =============================================================================
// Scan #49 PR B — BorderRadius hoist load-bearing tests (6 hoists, 3 files).
//
// Each test proves the hoisted `static final` BorderRadius field returns the
// SAME object instance across rebuilds. If someone reverts to inline
// BorderRadius.circular(N), each build produces a new instance →
// identical() fails → test RED.
//
// Hoists under test:
//   channels_tab_page.dart:  _kSearchBorderRadius
//   create_channel_page.dart: _kInputBorderRadius, _kCardBorderRadius
//   members_page.dart:        _kSearchBorderRadius, _kPillBorderRadius,
//                             _kLinkCardBorderRadius
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/channels/presentation/page/create_channel_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/channel_sort_preference.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/presentation/page/members_page.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ===========================================================================
  // H1: ChannelsTabPage — _kSearchBorderRadius (dual-pump)
  // ===========================================================================
  group('Scan #49 BorderRadius hoist — ChannelsTabPage search field', () {
    testWidgets('OutlineInputBorder borderRadius is identical across rebuilds',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
          channelSortPreferenceProvider
              .overrideWith(() => _FixedSortPreferenceNotifier()),
          unreadSourceProjectionProvider.overrideWithValue(
            UnreadSourceProjectionState(isLoaded: true),
          ),
          channelManagementStoreProvider
              .overrideWith(() => _FakeChannelManagementStore()),
          channelMutedIdsProvider.overrideWith((ref) => <String>{}),
          homeNowProvider.overrideWith(
            (ref) => Stream.value(DateTime.now()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/channels',
              routes: [
                GoRoute(
                  path: '/channels',
                  builder: (_, __) => const ChannelsTabPage(),
                ),
              ],
            ),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Extract borderRadius from the search TextField.
      final tf1 = tester.widget<TextField>(
        find.byKey(const ValueKey('channels-tab-search')),
      );
      final br1 = (tf1.decoration!.border as OutlineInputBorder).borderRadius;

      // Force rebuild — change unread count.
      container.updateOverrides([
        homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
        channelSortPreferenceProvider
            .overrideWith(() => _FixedSortPreferenceNotifier()),
        unreadSourceProjectionProvider.overrideWithValue(
          UnreadSourceProjectionState(
            channelUnreadCounts: {
              const ChannelScopeId(
                serverId: ServerScopeId('s1'),
                value: 'ch-1',
              ): 5,
            },
            isLoaded: true,
          ),
        ),
        channelManagementStoreProvider
            .overrideWith(() => _FakeChannelManagementStore()),
        channelMutedIdsProvider.overrideWith((ref) => <String>{}),
        homeNowProvider.overrideWith(
          (ref) => Stream.value(DateTime.now()),
        ),
      ]);
      await tester.pumpAndSettle();

      final tf2 = tester.widget<TextField>(
        find.byKey(const ValueKey('channels-tab-search')),
      );
      final br2 = (tf2.decoration!.border as OutlineInputBorder).borderRadius;

      expect(
        identical(br1, br2),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(radiusMd) → '
            'new instance each build → RED.',
      );
    });
  });

  // ===========================================================================
  // H2: CreateChannelPage — _kInputBorderRadius (dual-pump)
  // ===========================================================================
  group('Scan #49 BorderRadius hoist — CreateChannelPage input fields', () {
    testWidgets(
      'name + description fields share hoisted borderRadius across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              channelManagementStoreProvider
                  .overrideWith(() => _FakeChannelManagementStore()),
              activeServerScopeIdProvider
                  .overrideWithValue(const ServerScopeId('s1')),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CreateChannelPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Extract from name field.
        final tf1 = tester.widget<TextField>(
          find.byKey(const ValueKey('create-channel-name')),
        );
        final brName1 =
            (tf1.decoration!.border as OutlineInputBorder).borderRadius;

        // Extract from description field.
        final tf2 = tester.widget<TextField>(
          find.byKey(const ValueKey('create-channel-description')),
        );
        final brDesc1 =
            (tf2.decoration!.border as OutlineInputBorder).borderRadius;

        // Both must be the same instance (shared static final).
        expect(
          identical(brName1, brDesc1),
          isTrue,
          reason: 'Name and description fields must share the same hoisted '
              '_kInputBorderRadius instance.',
        );

        // Force rebuild by typing into the name field.
        await tester.enterText(
          find.byKey(const ValueKey('create-channel-name')),
          'test',
        );
        await tester.pumpAndSettle();

        // Re-extract.
        final tf1b = tester.widget<TextField>(
          find.byKey(const ValueKey('create-channel-name')),
        );
        final brName2 =
            (tf1b.decoration!.border as OutlineInputBorder).borderRadius;

        expect(
          identical(brName1, brName2),
          isTrue,
          reason: 'Reverting to inline BorderRadius.circular(12) → '
              'new instance each build → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H3: CreateChannelPage _VisibilityOption — _kCardBorderRadius (dual-pump)
  // ===========================================================================
  group('Scan #49 BorderRadius hoist — CreateChannelPage visibility cards', () {
    testWidgets(
      'AnimatedContainer borderRadius is identical across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              channelManagementStoreProvider
                  .overrideWith(() => _FakeChannelManagementStore()),
              activeServerScopeIdProvider
                  .overrideWithValue(const ServerScopeId('s1')),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CreateChannelPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the public visibility option AnimatedContainer.
        final publicFinder =
            find.byKey(const ValueKey('create-channel-visibility-public'));
        expect(publicFinder, findsOneWidget);

        // The AnimatedContainer is inside the GestureDetector.
        final animContainerFinder = find.descendant(
          of: publicFinder,
          matching: find.byType(AnimatedContainer),
        );
        final ac1 = tester.widget<AnimatedContainer>(animContainerFinder.first);
        final br1 = (ac1.decoration! as BoxDecoration).borderRadius;

        // Switch to private to trigger rebuild.
        await tester.tap(
          find.byKey(const ValueKey('create-channel-visibility-private')),
        );
        await tester.pumpAndSettle();

        // Re-extract from the now-deselected public option.
        final ac2 = tester.widget<AnimatedContainer>(animContainerFinder.first);
        final br2 = (ac2.decoration! as BoxDecoration).borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Reverting to inline BorderRadius.circular(12) in '
              '_VisibilityOption → new instance each build → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H4: MembersPage — _kSearchBorderRadius (dual-pump)
  // ===========================================================================
  group('Scan #49 BorderRadius hoist — MembersPage search field', () {
    testWidgets('OutlineInputBorder borderRadius is identical across rebuilds',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            memberListStoreProvider.overrideWith(() => _FakeMemberListStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MembersPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Extract borderRadius from the search TextField.
      final tf1 = tester.widget<TextField>(
        find.byKey(const ValueKey('members-search')),
      );
      final br1 = (tf1.decoration!.border as OutlineInputBorder).borderRadius;

      // Force rebuild by typing into search.
      await tester.enterText(
        find.byKey(const ValueKey('members-search')),
        'test',
      );
      await tester.pumpAndSettle();

      final tf2 = tester.widget<TextField>(
        find.byKey(const ValueKey('members-search')),
      );
      final br2 = (tf2.decoration!.border as OutlineInputBorder).borderRadius;

      expect(
        identical(br1, br2),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(radiusMd) → '
            'new instance each build → RED.',
      );
    });
  });

  // ===========================================================================
  // H5+H6: MembersPage _InviteHumanSheet — _kPillBorderRadius +
  //         _kLinkCardBorderRadius (dual-pump via sheet open/rebuild)
  // ===========================================================================
  group('Scan #49 BorderRadius hoist — _InviteHumanSheet', () {
    testWidgets(
      'pill drag-handle borderRadius is identical across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              memberListStoreProvider
                  .overrideWith(() => _FakeMemberListStore()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MembersPage(serverId: 'server-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open invite sheet.
        await tester.tap(
          find.byKey(const ValueKey('members-invite-human')),
        );
        await tester.pumpAndSettle();

        // The drag handle is a 32x4 Container with borderRadius.
        final dragHandleFinder = find.byWidgetPredicate(
          (w) {
            if (w is! Container) return false;
            if (w.decoration is! BoxDecoration) return false;
            final d = w.decoration! as BoxDecoration;
            if (d.borderRadius == null) return false;
            final c = w.constraints;
            return c != null && c.maxWidth == 32 && c.maxHeight == 4;
          },
        );
        expect(dragHandleFinder, findsOneWidget);

        final dh1 = tester.widget<Container>(dragHandleFinder);
        final br1 = (dh1.decoration! as BoxDecoration).borderRadius;

        // Force rebuild by typing in email field (triggers setState).
        await tester.enterText(
          find.byKey(const ValueKey('members-invite-email-field')),
          'a@b.com',
        );
        await tester.pumpAndSettle();

        final dh2 = tester.widget<Container>(dragHandleFinder);
        final br2 = (dh2.decoration! as BoxDecoration).borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Reverting to inline BorderRadius.circular(radiusFull) → '
              'new instance each build → RED.',
        );
      },
    );

    testWidgets(
      'link card borderRadius is identical across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              memberListStoreProvider
                  .overrideWith(() => _FakeMemberListStoreWithInvite()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MembersPage(serverId: 'server-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open invite sheet.
        await tester.tap(
          find.byKey(const ValueKey('members-invite-human')),
        );
        await tester.pumpAndSettle();

        // Generate invite link by tapping the generate button.
        await tester.tap(
          find.byKey(const ValueKey('members-invite-generate-link')),
        );
        await tester.pumpAndSettle();

        // Now the link card Container should be visible.
        final linkTextFinder = find.byKey(
          const ValueKey('members-invite-link-text'),
        );
        expect(linkTextFinder, findsOneWidget);

        // Find the Container ancestor of the link text that has BoxDecoration.
        final containerFinder = find.ancestor(
          of: linkTextFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).borderRadius != null,
          ),
        );
        expect(containerFinder, findsOneWidget);

        final c1 = tester.widget<Container>(containerFinder.first);
        final br1 = (c1.decoration! as BoxDecoration).borderRadius;

        // Force rebuild by typing in email field.
        await tester.enterText(
          find.byKey(const ValueKey('members-invite-email-field')),
          'x@y.com',
        );
        await tester.pumpAndSettle();

        final c2 = tester.widget<Container>(containerFinder.first);
        final br2 = (c2.decoration! as BoxDecoration).borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Reverting to inline BorderRadius.circular(radiusMd) → '
              'new instance each build → RED.',
        );
      },
    );
  });
}

// =============================================================================
// Fakes — ChannelsTabPage
// =============================================================================

class _FakeHomeListStore extends Notifier<HomeListState>
    implements HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        channels: const [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('s1'),
              value: 'ch-1',
            ),
            name: 'general',
          ),
        ],
        pinnedChannels: const [],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedSortPreferenceNotifier extends Notifier<ChannelSortPreference>
    implements ChannelSortPreferenceNotifier {
  @override
  ChannelSortPreference build() => ChannelSortPreference.recentActivity;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChannelManagementStore
    extends AutoDisposeNotifier<ChannelManagementState>
    implements ChannelManagementStore {
  @override
  ChannelManagementState build() => const ChannelManagementState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// Fakes — MembersPage
// =============================================================================

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-me',
        displayName: 'Me',
        token: 'test-token',
      );
}

class _FakeMemberListStore extends MemberListStore {
  @override
  MemberListState build() {
    return MemberListState(
      status: MemberListStatus.success,
      members: const [
        MemberProfile(
          id: 'user-me',
          displayName: 'Me',
          role: 'owner',
          isSelf: true,
        ),
        MemberProfile(
          id: 'user-target',
          displayName: 'Target',
          role: 'member',
        ),
      ],
    );
  }

  @override
  Future<void> ensureLoaded() async {}

  @override
  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  @override
  Future<String> createInvite() async => 'https://invite.example.com/abc';

  @override
  Future<void> inviteByEmail(String email) async {}
}

/// Same as _FakeMemberListStore but also immediately returns an invite link.
class _FakeMemberListStoreWithInvite extends MemberListStore {
  @override
  MemberListState build() {
    return MemberListState(
      status: MemberListStatus.success,
      members: const [
        MemberProfile(
          id: 'user-me',
          displayName: 'Me',
          role: 'owner',
          isSelf: true,
        ),
        MemberProfile(
          id: 'user-target',
          displayName: 'Target',
          role: 'member',
        ),
      ],
    );
  }

  @override
  Future<void> ensureLoaded() async {}

  @override
  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  @override
  Future<String> createInvite() async => 'https://invite.example.com/abc';

  @override
  Future<void> inviteByEmail(String email) async {}
}
