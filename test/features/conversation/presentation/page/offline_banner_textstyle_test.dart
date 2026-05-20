// =============================================================================
// #655 — OfflineBanner Riverpod migration + TextStyle const hoist
//
// Invariants verified:
// INV-OFFLINE-RIVERPOD-1: _OfflineBanner renders from connectivityStatusProvider
//                         (not raw StreamBuilder).
// INV-OFFLINE-RIVERPOD-2: _OfflineBanner hides when status is online.
// INV-TEXTSTYLE-CONST-1: AppTypography.labelBold is pre-computed with w600
//                         (no per-build copyWith for fontWeight).
// INV-TEXTSTYLE-CONST-2: AppTypography.captionBold is pre-computed with w600.
// INV-TEXTSTYLE-PROD-1: ConversationMessageCard sender name uses labelBold base.
// INV-TEXTSTYLE-PROD-2: ConversationMessageCard AI badge uses captionBold base.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  // ---------------------------------------------------------------------------
  // INV-OFFLINE-RIVERPOD-1 & 2: OfflineBanner via connectivityStatusProvider
  // ---------------------------------------------------------------------------
  group('INV-OFFLINE-RIVERPOD: OfflineBanner renders via Riverpod provider',
      () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets(
      'INV-OFFLINE-RIVERPOD-1: shows offline banner when status is offline',
      (tester) async {
        final controller = StreamController<ConnectivityStatus>.broadcast();
        final service = ConnectivityService.withInitialStatus(
          ConnectivityStatus.offline,
          controller: controller,
        );

        await tester.pumpWidget(_buildApp(
          prefs: prefs,
          connectivityService: service,
        ));
        await tester.pumpAndSettle();

        // The real _OfflineBanner should render via connectivityStatusProvider.
        expect(
          find.byKey(const ValueKey('offline-banner')),
          findsOneWidget,
          reason: 'Offline banner must show when connectivityStatusProvider '
              'returns offline (INV-OFFLINE-RIVERPOD-1)',
        );
        expect(
          find.text(
              'You are offline. Messages will be sent when you reconnect.'),
          findsOneWidget,
        );

        controller.close();
        service.dispose();
      },
    );

    testWidgets(
      'INV-OFFLINE-RIVERPOD-2: hides offline banner when status is online',
      (tester) async {
        final controller = StreamController<ConnectivityStatus>.broadcast();
        final service = ConnectivityService.withInitialStatus(
          ConnectivityStatus.online,
          controller: controller,
        );

        await tester.pumpWidget(_buildApp(
          prefs: prefs,
          connectivityService: service,
        ));
        await tester.pumpAndSettle();

        // Should NOT show the banner when online.
        expect(
          find.byKey(const ValueKey('offline-banner')),
          findsNothing,
          reason: 'Offline banner must be hidden when online '
              '(INV-OFFLINE-RIVERPOD-2)',
        );

        controller.close();
        service.dispose();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-TEXTSTYLE-CONST-1 & 2: Pre-computed TextStyle constants
  // ---------------------------------------------------------------------------
  group('INV-TEXTSTYLE-CONST: pre-computed bold style variants', () {
    test(
      'INV-TEXTSTYLE-CONST-1: labelBold has fontWeight w600 pre-applied',
      () {
        expect(AppTypography.labelBold.fontWeight, FontWeight.w600);
        expect(AppTypography.labelBold.fontSize, AppTypography.label.fontSize);
        expect(
          AppTypography.labelBold.letterSpacing,
          AppTypography.label.letterSpacing,
        );
        expect(AppTypography.labelBold.height, AppTypography.label.height);
      },
    );

    test(
      'INV-TEXTSTYLE-CONST-2: captionBold has fontWeight w600 pre-applied',
      () {
        expect(AppTypography.captionBold.fontWeight, FontWeight.w600);
        expect(
          AppTypography.captionBold.fontSize,
          AppTypography.caption.fontSize,
        );
        expect(
          AppTypography.captionBold.letterSpacing,
          AppTypography.caption.letterSpacing,
        );
        expect(AppTypography.captionBold.height, AppTypography.caption.height);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-TEXTSTYLE-PROD-1 & 2: Production-path — real ConversationMessageCard
  // renders sender name / AI badge using pre-computed bold styles.
  // ---------------------------------------------------------------------------
  group('INV-TEXTSTYLE-PROD: ConversationMessageCard uses pre-computed styles',
      () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets(
      'INV-TEXTSTYLE-PROD-1: sender name Text uses labelBold base '
      '(fontWeight w600, fontSize 12, letterSpacing 0.1)',
      (tester) async {
        final controller = StreamController<ConnectivityStatus>.broadcast();
        final service = ConnectivityService.withInitialStatus(
          ConnectivityStatus.online,
          controller: controller,
        );

        await tester.pumpWidget(_buildAppWithAgentMessage(
          prefs: prefs,
          connectivityService: service,
        ));
        await tester.pumpAndSettle();

        // Find the sender name text 'BotAgent'.
        final senderFinder = find.text('BotAgent');
        expect(senderFinder, findsOneWidget,
            reason: 'Agent sender name must render');

        // Extract the Text widget's effective style.
        final textWidget = tester.widget<Text>(senderFinder);
        final style = textWidget.style!;

        // Assert it uses labelBold base properties.
        expect(style.fontWeight, FontWeight.w600,
            reason: 'Sender name must use w600 from labelBold '
                '(INV-TEXTSTYLE-PROD-1)');
        expect(style.fontSize, AppTypography.labelBold.fontSize,
            reason: 'Sender name fontSize must match labelBold');
        expect(style.letterSpacing, AppTypography.labelBold.letterSpacing,
            reason: 'Sender name letterSpacing must match labelBold');
        expect(style.height, AppTypography.labelBold.height,
            reason: 'Sender name height must match labelBold');

        controller.close();
        service.dispose();
      },
    );

    testWidgets(
      'INV-TEXTSTYLE-PROD-2: AI badge Text uses captionBold base '
      '(fontWeight w600, fontSize 11, letterSpacing 0.15)',
      (tester) async {
        final controller = StreamController<ConnectivityStatus>.broadcast();
        final service = ConnectivityService.withInitialStatus(
          ConnectivityStatus.online,
          controller: controller,
        );

        await tester.pumpWidget(_buildAppWithAgentMessage(
          prefs: prefs,
          connectivityService: service,
        ));
        await tester.pumpAndSettle();

        // Find the 'AI' badge text.
        final aiBadgeFinder = find.text('AI');
        expect(aiBadgeFinder, findsOneWidget,
            reason: 'AI badge must render for agent messages');

        // Extract the Text widget's effective style.
        final textWidget = tester.widget<Text>(aiBadgeFinder);
        final style = textWidget.style!;

        // Assert it uses captionBold base properties.
        expect(style.fontWeight, FontWeight.w600,
            reason: 'AI badge must use w600 from captionBold '
                '(INV-TEXTSTYLE-PROD-2)');
        expect(style.fontSize, AppTypography.captionBold.fontSize,
            reason: 'AI badge fontSize must match captionBold');
        expect(style.letterSpacing, AppTypography.captionBold.letterSpacing,
            reason: 'AI badge letterSpacing must match captionBold');
        expect(style.height, AppTypography.captionBold.height,
            reason: 'AI badge height must match captionBold');

        controller.close();
        service.dispose();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _target = ConversationDetailTarget.channel(
  const ChannelScopeId(
    serverId: ServerScopeId('server-1'),
    value: 'ch-1',
  ),
);

Widget _buildApp({
  required SharedPreferences prefs,
  required ConnectivityService connectivityService,
}) {
  return ProviderScope(
    overrides: [
      conversationDetailStoreProvider
          .overrideWith(() => _FakeConversationDetailStore()),
      conversationDetailSessionStoreProvider
          .overrideWith(() => _FakeSessionDetailStore()),
      voiceMessageStoreProvider.overrideWith(() => _FakeVoiceMessageStore()),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      realtimeReductionIngressProvider
          .overrideWithValue(RealtimeReductionIngress()),
      connectivityServiceProvider.overrideWithValue(connectivityService),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ConversationDetailPage(
        target: _target,
        registerOpenTarget: false,
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

/// Build app with an agent message so the sender label + AI badge render.
Widget _buildAppWithAgentMessage({
  required SharedPreferences prefs,
  required ConnectivityService connectivityService,
}) {
  return ProviderScope(
    overrides: [
      conversationDetailStoreProvider
          .overrideWith(() => _FakeConversationDetailStoreWithAgent()),
      conversationDetailSessionStoreProvider
          .overrideWith(() => _FakeSessionDetailStore()),
      voiceMessageStoreProvider.overrideWith(() => _FakeVoiceMessageStore()),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      realtimeReductionIngressProvider
          .overrideWithValue(RealtimeReductionIngress()),
      connectivityServiceProvider.overrideWithValue(connectivityService),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ConversationDetailPage(
        target: _target,
        registerOpenTarget: false,
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConversationDetailStore extends ConversationDetailStore {
  @override
  ConversationDetailState build() => ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
        messages: const [],
      );

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> refresh({String reason = 'manual'}) async {}

  @override
  Future<void> loadOlder() async {}

  @override
  Future<void> loadNewer() async {}
}

class _FakeSessionDetailStore extends ConversationDetailSessionStore {
  @override
  Map<ConversationDetailTarget, ConversationDetailSessionEntry> build() =>
      const {};
}

class _FakeVoiceMessageStore extends VoiceMessageStore {
  @override
  VoiceMessageState build() => const VoiceMessageState();
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

class _FakeHomeListStore extends HomeListStore {
  @override
  HomeListState build() => const HomeListState(
        status: HomeListStatus.success,
      );
}

/// Fake store returning an agent-type message so the sender label and
/// AI badge render in the production widget tree.
class _FakeConversationDetailStoreWithAgent extends ConversationDetailStore {
  @override
  ConversationDetailState build() => ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
        messages: [
          ConversationMessageSummary(
            id: 'msg-agent-1',
            content: 'Hello from bot',
            createdAt: DateTime.parse('2026-05-20T10:00:00Z'),
            senderId: 'agent-1',
            senderType: 'agent',
            messageType: 'message',
            senderName: 'BotAgent',
            seq: 1,
          ),
        ],
      );

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> refresh({String reason = 'manual'}) async {}

  @override
  Future<void> loadOlder() async {}

  @override
  Future<void> loadNewer() async {}
}
