// ---------------------------------------------------------------------------
// #558: Preview/Status i18n — Hardcoded Chinese → l10n ARB system
//
// Problem:
//   1. `message_preview_resolver.dart:44-52`: All 10 inbox preview strings
//      hardcoded in Chinese. Non-Chinese users see Chinese text in inbox rows,
//      push notifications, and home sidebar.
//   2. `message_preview_resolver.dart:96`: Attachment preview uses Chinese
//      interpolation `'附件: ${name}'` instead of l10n template.
//   3. `agent_display_status.dart:40-47`: 6 agent status labels hardcoded
//      in Chinese.
//   4. `agent_status_group.dart:36`: Chinese enumeration comma `、` instead
//      of locale-aware separator.
//
// Phase A: skip:true invariants locking the i18n contracts.
//          Tests load AppLocalizations for BOTH 'en' and 'zh' locales and
//          verify resolver / status functions produce locale-appropriate
//          output. Multi-locale assertions prove l10n wiring — hardcoding
//          either language fails the other locale's check.
//
// Invariants verified:
// INV-I18N-PREVIEW-1: All 10 preview constants resolve via AppLocalizations
// INV-I18N-PREVIEW-2: Dynamic attachment preview uses l10n template
// INV-I18N-STATUS-1:  All 6 displayStatusLabel values resolve via l10n
// INV-I18N-GROUP-1:   mergedSummary uses locale-aware separator (not 、)
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agent_display_status.dart';
import 'package:slock_app/features/agents/application/agent_status_group.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  /// English and Chinese AppLocalizations for dual-locale assertions.
  late AppLocalizations enL10n;
  late AppLocalizations zhL10n;

  setUpAll(() async {
    enL10n = await AppLocalizations.delegate.load(const Locale('en'));
    zhL10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  // -----------------------------------------------------------------------
  // INV-I18N-PREVIEW-1: All 10 preview constants resolve via l10n
  //
  // Each test passes both en and zh l10n to the same API and verifies:
  //   1. en result matches en ARB value
  //   2. zh result matches zh ARB value
  //   3. en and zh results differ (proves wiring, not hardcoding)
  // -----------------------------------------------------------------------
  group('INV-I18N-PREVIEW-1: preview constants use l10n', () {
    test(
      'deleted preview resolves per locale',
      () {
        expect(enL10n.previewDeleted, isNot(equals(zhL10n.previewDeleted)),
            reason: 'Precondition: en/zh ARB values must differ');

        final enResult =
            MessagePreviewResolver.resolve(l10n: enL10n, isDeleted: true);
        final zhResult =
            MessagePreviewResolver.resolve(l10n: zhL10n, isDeleted: true);

        expect(enResult, equals(enL10n.previewDeleted),
            reason: 'English locale must return English deleted preview');
        expect(zhResult, equals(zhL10n.previewDeleted),
            reason: 'Chinese locale must return Chinese deleted preview');
        expect(enResult, isNot(equals(zhResult)),
            reason: 'Locales must produce different results');
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'sending preview resolves per locale',
      () {
        expect(enL10n.previewSending, isNot(equals(zhL10n.previewSending)),
            reason: 'Precondition: en/zh ARB values must differ');

        final enResult = MessagePreviewResolver.resolve(
          l10n: enL10n,
          sendState: MessageSendState.sending,
        );
        final zhResult = MessagePreviewResolver.resolve(
          l10n: zhL10n,
          sendState: MessageSendState.sending,
        );

        expect(enResult, equals(enL10n.previewSending));
        expect(zhResult, equals(zhL10n.previewSending));
        expect(enResult, isNot(equals(zhResult)));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'failed preview resolves per locale',
      () {
        expect(enL10n.previewFailed, isNot(equals(zhL10n.previewFailed)),
            reason: 'Precondition: en/zh ARB values must differ');

        final enResult = MessagePreviewResolver.resolve(
          l10n: enL10n,
          sendState: MessageSendState.failed,
        );
        final zhResult = MessagePreviewResolver.resolve(
          l10n: zhL10n,
          sendState: MessageSendState.failed,
        );

        expect(enResult, equals(enL10n.previewFailed));
        expect(zhResult, equals(zhL10n.previewFailed));
        expect(enResult, isNot(equals(zhResult)));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'system preview resolves per locale',
      () {
        expect(enL10n.previewSystem, isNot(equals(zhL10n.previewSystem)),
            reason: 'Precondition: en/zh ARB values must differ');

        final enResult =
            MessagePreviewResolver.resolve(l10n: enL10n, messageType: 'system');
        final zhResult =
            MessagePreviewResolver.resolve(l10n: zhL10n, messageType: 'system');

        expect(enResult, equals(enL10n.previewSystem));
        expect(zhResult, equals(zhL10n.previewSystem));
        expect(enResult, isNot(equals(zhResult)));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'link preview resolves per locale',
      () {
        expect(enL10n.previewLink, isNot(equals(zhL10n.previewLink)),
            reason: 'Precondition: en/zh ARB values must differ');

        final enResult = MessagePreviewResolver.resolve(
          l10n: enL10n,
          content: 'https://example.com',
        );
        final zhResult = MessagePreviewResolver.resolve(
          l10n: zhL10n,
          content: 'https://example.com',
        );

        expect(enResult, equals(enL10n.previewLink));
        expect(zhResult, equals(zhL10n.previewLink));
        expect(enResult, isNot(equals(zhResult)));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'voice preview resolves per locale',
      () {
        expect(enL10n.previewVoice, isNot(equals(zhL10n.previewVoice)),
            reason: 'Precondition: en/zh ARB values must differ');

        const voiceAttachment = [
          MessageAttachment(
            name: 'recording.ogg',
            type: 'audio/ogg',
            url: 'https://example.com/audio.ogg',
            id: 'att-1',
          ),
        ];

        final enResult = MessagePreviewResolver.resolve(
          l10n: enL10n,
          attachments: voiceAttachment,
        );
        final zhResult = MessagePreviewResolver.resolve(
          l10n: zhL10n,
          attachments: voiceAttachment,
        );

        expect(enResult, equals(enL10n.previewVoice));
        expect(zhResult, equals(zhL10n.previewVoice));
        expect(enResult, isNot(equals(zhResult)));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'image preview resolves per locale',
      () {
        expect(enL10n.previewImage, isNot(equals(zhL10n.previewImage)),
            reason: 'Precondition: en/zh ARB values must differ');

        const imageAttachment = [
          MessageAttachment(
            name: 'photo.jpg',
            type: 'image/jpeg',
            url: 'https://example.com/photo.jpg',
            id: 'att-1',
          ),
        ];

        final enResult = MessagePreviewResolver.resolve(
          l10n: enL10n,
          attachments: imageAttachment,
        );
        final zhResult = MessagePreviewResolver.resolve(
          l10n: zhL10n,
          attachments: imageAttachment,
        );

        expect(enResult, equals(enL10n.previewImage));
        expect(zhResult, equals(zhL10n.previewImage));
        expect(enResult, isNot(equals(zhResult)));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'video preview resolves per locale',
      () {
        expect(enL10n.previewVideo, isNot(equals(zhL10n.previewVideo)),
            reason: 'Precondition: en/zh ARB values must differ');

        const videoAttachment = [
          MessageAttachment(
            name: 'clip.mp4',
            type: 'video/mp4',
            url: 'https://example.com/clip.mp4',
            id: 'att-1',
          ),
        ];

        final enResult = MessagePreviewResolver.resolve(
          l10n: enL10n,
          attachments: videoAttachment,
        );
        final zhResult = MessagePreviewResolver.resolve(
          l10n: zhL10n,
          attachments: videoAttachment,
        );

        expect(enResult, equals(enL10n.previewVideo));
        expect(zhResult, equals(zhL10n.previewVideo));
        expect(enResult, isNot(equals(zhResult)));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'fallback preview resolves per locale',
      () {
        expect(enL10n.previewFallback, isNot(equals(zhL10n.previewFallback)),
            reason: 'Precondition: en/zh ARB values must differ');

        final enResult = MessagePreviewResolver.resolve(l10n: enL10n);
        final zhResult = MessagePreviewResolver.resolve(l10n: zhL10n);

        expect(enResult, equals(enL10n.previewFallback));
        expect(zhResult, equals(zhL10n.previewFallback));
        expect(enResult, isNot(equals(zhResult)));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );
  });

  // -----------------------------------------------------------------------
  // INV-I18N-PREVIEW-2: Attachment preview uses l10n template
  // -----------------------------------------------------------------------
  group('INV-I18N-PREVIEW-2: attachment preview l10n template', () {
    test(
      'generic attachment preview uses l10n template per locale',
      () {
        const filename = 'document.pdf';

        expect(
          enL10n.previewAttachment(filename),
          isNot(equals(zhL10n.previewAttachment(filename))),
          reason: 'Precondition: en/zh attachment templates must differ',
        );

        const pdfAttachment = [
          MessageAttachment(
            name: filename,
            type: 'application/pdf',
            url: 'https://example.com/doc.pdf',
            id: 'att-1',
          ),
        ];

        final enResult = MessagePreviewResolver.resolve(
          l10n: enL10n,
          attachments: pdfAttachment,
        );
        final zhResult = MessagePreviewResolver.resolve(
          l10n: zhL10n,
          attachments: pdfAttachment,
        );

        expect(enResult, equals(enL10n.previewAttachment(filename)),
            reason: 'English attachment must use l10n template');
        expect(zhResult, equals(zhL10n.previewAttachment(filename)),
            reason: 'Chinese attachment must use l10n template');
        expect(enResult, isNot(equals(zhResult)),
            reason: 'Locales must produce different templates');
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );
  });

  // -----------------------------------------------------------------------
  // INV-I18N-STATUS-1: All 6 displayStatusLabel values use l10n
  // -----------------------------------------------------------------------
  group('INV-I18N-STATUS-1: agent status labels use l10n', () {
    test(
      'all 6 displayStatusLabel values resolve per locale',
      () {
        final enExpected = {
          AgentDisplayStatus.thinking: enL10n.agentStatusThinking,
          AgentDisplayStatus.working: enL10n.agentStatusWorking,
          AgentDisplayStatus.error: enL10n.agentStatusError,
          AgentDisplayStatus.online: enL10n.agentStatusOnline,
          AgentDisplayStatus.offline: enL10n.agentStatusOffline,
          AgentDisplayStatus.stopped: enL10n.agentStatusStopped,
        };
        final zhExpected = {
          AgentDisplayStatus.thinking: zhL10n.agentStatusThinking,
          AgentDisplayStatus.working: zhL10n.agentStatusWorking,
          AgentDisplayStatus.error: zhL10n.agentStatusError,
          AgentDisplayStatus.online: zhL10n.agentStatusOnline,
          AgentDisplayStatus.offline: zhL10n.agentStatusOffline,
          AgentDisplayStatus.stopped: zhL10n.agentStatusStopped,
        };

        for (final status in AgentDisplayStatus.values) {
          final enResult = displayStatusLabel(status, l10n: enL10n);
          final zhResult = displayStatusLabel(status, l10n: zhL10n);

          expect(enResult, equals(enExpected[status]),
              reason: '${status.name} English label must match en l10n value');
          expect(zhResult, equals(zhExpected[status]),
              reason: '${status.name} Chinese label must match zh l10n value');
          expect(enResult, isNot(equals(zhResult)),
              reason:
                  '${status.name} must produce different results per locale');
        }
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );
  });

  // -----------------------------------------------------------------------
  // INV-I18N-GROUP-1: mergedSummary uses locale-aware separator
  //
  // mergedSummary({AppLocalizations? l10n}) delegates to displayStatusLabel()
  // and uses locale-appropriate separator. Dual-locale assertion: en → ', ',
  // zh → '、', with locale-appropriate status labels.
  // -----------------------------------------------------------------------
  group('INV-I18N-GROUP-1: mergedSummary locale-aware separator', () {
    test(
      'mergedSummary produces locale-aware output per locale',
      () {
        final group = AgentStatusGroup(
          displayStatus: AgentDisplayStatus.thinking,
          agents: const [
            AgentItem(
              id: 'a1',
              name: 'alpha-agent',
              displayName: 'Alpha',
              model: 'test',
              runtime: 'test',
              status: 'active',
              activity: 'thinking',
            ),
            AgentItem(
              id: 'a2',
              name: 'beta-agent',
              displayName: 'Beta',
              model: 'test',
              runtime: 'test',
              status: 'active',
              activity: 'thinking',
            ),
          ],
        );

        final enSummary = group.mergedSummary(l10n: enL10n);
        final zhSummary = group.mergedSummary(l10n: zhL10n);

        // English: "Alpha, Beta Thinking"
        expect(enSummary, contains(', '),
            reason: 'English mergedSummary must use comma separator');
        expect(enSummary, contains(enL10n.agentStatusThinking),
            reason: 'English summary must use English status label');

        // Chinese: "Alpha、Beta 思考中"
        expect(zhSummary, contains('、'),
            reason: 'Chinese mergedSummary must use Chinese comma 、');
        expect(zhSummary, contains(zhL10n.agentStatusThinking),
            reason: 'Chinese summary must use Chinese status label');

        // Dual-locale: results must differ (proves l10n wiring).
        expect(enSummary, isNot(equals(zhSummary)),
            reason: 'Locales must produce different summaries');
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );
  });
}
