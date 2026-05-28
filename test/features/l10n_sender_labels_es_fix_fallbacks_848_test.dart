// =============================================================================
// #848 — L10n Sender Labels + ES ¿ Fix + Inbox/Share Fallbacks
//
// Load-bearing tests:
// 1. Sender labels: Under ZH locale, widget displays Chinese sender label
//    (reverting to hardcoded English → RED)
// 2. ES inverted question mark: Forgot-password under ES shows ¿
//    (removing ¿ from ARB → RED)
// 3. Share attachment count: Under ZH locale, shows Chinese plural
//    (reverting to hardcoded English → RED)
// 4. Inbox resolver fallback: Under ZH-aware resolver, DM fallback is Chinese
//    (removing l10n from resolver → RED)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/utils/sender_label_l10n.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_export_card.dart';
import 'package:slock_app/features/inbox/application/inbox_name_resolver.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/widgets/share_preview_card.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  // ===========================================================================
  // Group 1: Sender labels localized under ZH
  // ===========================================================================
  group('#848 — Sender labels l10n', () {
    test('localizedSenderLabel returns Chinese for agent under zh locale', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final msg = ConversationMessageSummary(
        id: 'msg-1',
        content: 'hello',
        createdAt: DateTime(2026, 5, 1),
        senderType: 'agent',
        messageType: 'text',
      );
      expect(msg.localizedSenderLabel(l10n), '智能体');
    });

    test('localizedSenderLabel returns Chinese for member under zh locale', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final msg = ConversationMessageSummary(
        id: 'msg-2',
        content: 'hi',
        createdAt: DateTime(2026, 5, 1),
        senderType: 'human',
        messageType: 'text',
      );
      expect(msg.localizedSenderLabel(l10n), '成员');
    });

    test('localizedSenderLabel returns Chinese for system under zh locale', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final msg = ConversationMessageSummary(
        id: 'msg-3',
        content: 'joined',
        createdAt: DateTime(2026, 5, 1),
        senderType: 'bot',
        messageType: 'system',
      );
      expect(msg.localizedSenderLabel(l10n), '系统');
    });

    test('localizedSenderLabel returns senderName when available', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final msg = ConversationMessageSummary(
        id: 'msg-4',
        content: 'hi',
        createdAt: DateTime(2026, 5, 1),
        senderType: 'agent',
        senderName: 'Claude',
        messageType: 'text',
      );
      expect(msg.localizedSenderLabel(l10n), 'Claude');
    });

    test('ReplyToSummary localizedSenderLabel returns Chinese for agent', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      const reply = ReplyToSummary(
        id: 'r-1',
        content: 'quote',
        senderType: 'agent',
      );
      expect(reply.localizedSenderLabel(l10n), '智能体');
    });

    test('localizedSenderLabel returns English under en locale', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final msg = ConversationMessageSummary(
        id: 'msg-5',
        content: 'hello',
        createdAt: DateTime(2026, 5, 1),
        senderType: 'agent',
        messageType: 'text',
      );
      expect(msg.localizedSenderLabel(l10n), 'Agent');
    });

    test('localizedSenderLabel returns Spanish under es locale', () {
      final l10n = lookupAppLocalizations(const Locale('es'));
      final msg = ConversationMessageSummary(
        id: 'msg-6',
        content: 'hola',
        createdAt: DateTime(2026, 5, 1),
        senderType: 'agent',
        messageType: 'text',
      );
      expect(msg.localizedSenderLabel(l10n), 'Agente');
    });
  });

  // ===========================================================================
  // Group 2: ES inverted question mark
  // ===========================================================================
  group('#848 — ES inverted ¿ fix', () {
    test('loginForgotPasswordCta starts with ¿ in Spanish', () {
      final l10n = lookupAppLocalizations(const Locale('es'));
      expect(
        l10n.loginForgotPasswordCta.startsWith('¿'),
        isTrue,
        reason: 'Spanish questions must begin with inverted question mark (¿). '
            'Removing ¿ from app_es.arb → this test fails RED.',
      );
    });

    test('loginForgotPasswordCta does not start with ¿ in English', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(l10n.loginForgotPasswordCta.startsWith('¿'), isFalse);
    });
  });

  // ===========================================================================
  // Group 3: Share preview attachment count localized
  // ===========================================================================
  group('#848 — Share preview attachment count l10n', () {
    testWidgets('shows Chinese attachment text under zh locale',
        (tester) async {
      const content = SharedContent(
        items: [
          SharedContentItem(
            type: SharedContentType.image,
            path: '/tmp/test.png',
            mimeType: 'image/png',
          ),
          SharedContentItem(
            type: SharedContentType.image,
            path: '/tmp/test2.png',
            mimeType: 'image/png',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const Scaffold(body: SharePreviewCard(content: content)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chinese plural: "2 个附件"
      expect(
        find.text('2 个附件'),
        findsOneWidget,
        reason: 'Under ZH locale, attachment count must use Chinese plural. '
            'Reverting to hardcoded English → RED.',
      );
      // English must NOT appear.
      expect(find.text('2 attachments'), findsNothing);
    });

    testWidgets('shows singular attachment text under zh locale',
        (tester) async {
      const content = SharedContent(
        items: [
          SharedContentItem(
            type: SharedContentType.image,
            path: '/tmp/test.png',
            mimeType: 'image/png',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const Scaffold(body: SharePreviewCard(content: content)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('1 个附件'),
        findsOneWidget,
        reason: 'Under ZH locale, singular attachment count must use Chinese.',
      );
    });
  });

  // ===========================================================================
  // Group 4: Inbox resolver localized fallbacks
  // ===========================================================================
  group('#848 — Inbox resolver l10n fallbacks', () {
    test('DM fallback uses Chinese when l10n is zh', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final resolver = InboxNameResolver(l10n: l10n);

      const item = InboxItem(
        channelId: 'dm-unknown-id',
        kind: InboxItemKind.dm,
      );

      final label = resolver.resolveSourceLabel(item);
      expect(
        label,
        '未知',
        reason: 'DM fallback must be localized Chinese "未知" when l10n=zh. '
            'Removing l10n from resolver → returns English "Unknown" → RED.',
      );
    });

    test('DM fallback uses English when l10n is null (backward compat)', () {
      final resolver = InboxNameResolver();

      const item = InboxItem(
        channelId: 'dm-unknown-id',
        kind: InboxItemKind.dm,
      );

      final label = resolver.resolveSourceLabel(item);
      expect(label, 'Unknown');
    });

    test('member name derivation fallback uses Chinese when l10n is zh', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final resolver = InboxNameResolver(l10n: l10n);

      // Unknown ID format — cannot derive name, falls back to "Member" / "成员"
      final name = resolver.resolveSenderName(senderId: 'random-uuid-123');
      expect(
        name,
        '成员',
        reason: 'Unrecognized sender ID must fall back to localized "成员" '
            'under ZH. Removing l10n → English "Member" → RED.',
      );
    });

    test('member name derivation fallback uses English when l10n is null', () {
      final resolver = InboxNameResolver();
      final name = resolver.resolveSenderName(senderId: 'random-uuid-123');
      expect(name, 'Member');
    });
  });

  // ===========================================================================
  // Group 5: Widget-level load-bearing proof (mounting real production widget)
  // ===========================================================================
  group('#848 — Widget-level sender label l10n proof', () {
    testWidgets(
        'MessageExportCard renders Chinese sender label under ZH locale',
        (tester) async {
      final messages = [
        ConversationMessageSummary(
          id: 'msg-widget-1',
          content: 'Test message',
          createdAt: DateTime(2026, 5, 1, 10, 30),
          senderType: 'agent',
          messageType: 'text',
          // No senderName → falls back to localizedSenderLabel → "智能体" in ZH
        ),
      ];
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageExportCard(
                messages: messages,
                boundaryKey: boundaryKey,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Widget must display Chinese sender label "智能体" (not English "Agent").
      // Reverting message_export_card.dart back to `.senderLabel` → this fails RED.
      expect(
        find.text('智能体'),
        findsOneWidget,
        reason:
            'MessageExportCard must render localized ZH sender label "智能体". '
            'Reverting to hardcoded .senderLabel → English "Agent" → RED.',
      );
      // English must NOT appear.
      expect(
        find.text('Agent'),
        findsNothing,
        reason: 'Under ZH locale, English "Agent" must not appear.',
      );
    });

    testWidgets(
        'MessageExportCard renders English sender label under EN locale',
        (tester) async {
      final messages = [
        ConversationMessageSummary(
          id: 'msg-widget-2',
          content: 'Hello',
          createdAt: DateTime(2026, 5, 1, 10, 30),
          senderType: 'human',
          messageType: 'text',
        ),
      ];
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageExportCard(
                messages: messages,
                boundaryKey: boundaryKey,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Member'),
        findsOneWidget,
        reason:
            'MessageExportCard must render English "Member" for human type.',
      );
    });
  });
}
