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
//          Tests load AppLocalizations for 'en' locale and verify that
//          resolver / status functions return English l10n strings.
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
  /// Load English AppLocalizations for assertion.
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // -----------------------------------------------------------------------
  // INV-I18N-PREVIEW-1: All 10 preview constants resolve via l10n
  // -----------------------------------------------------------------------
  group('INV-I18N-PREVIEW-1: preview constants use l10n', () {
    test(
      'deleted preview resolves to English l10n string',
      () {
        final result = MessagePreviewResolver.resolve(isDeleted: true);
        expect(result, equals(l10n.previewDeleted),
            reason: 'Deleted preview must use l10n, not hardcoded Chinese');
        expect(result, isNot(contains('消息已删除')),
            reason: 'Must not contain hardcoded Chinese');
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'sending preview resolves to English l10n string',
      () {
        final result = MessagePreviewResolver.resolve(
          sendState: MessageSendState.sending,
        );
        expect(result, equals(l10n.previewSending));
        expect(result, isNot(contains('正在发送')));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'failed preview resolves to English l10n string',
      () {
        final result = MessagePreviewResolver.resolve(
          sendState: MessageSendState.failed,
        );
        expect(result, equals(l10n.previewFailed));
        expect(result, isNot(contains('未发送')));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'system preview resolves to English l10n string',
      () {
        final result = MessagePreviewResolver.resolve(messageType: 'system');
        expect(result, equals(l10n.previewSystem));
        expect(result, isNot(contains('系统消息')));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'link preview resolves to English l10n string',
      () {
        final result = MessagePreviewResolver.resolve(
          content: 'https://example.com',
        );
        expect(result, equals(l10n.previewLink));
        expect(result, isNot(equals('链接')));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'voice preview resolves to English l10n string',
      () {
        final result = MessagePreviewResolver.resolve(
          attachments: const [
            MessageAttachment(
              name: 'recording.ogg',
              type: 'audio/ogg',
              url: 'https://example.com/audio.ogg',
              id: 'att-1',
            ),
          ],
        );
        expect(result, equals(l10n.previewVoice));
        expect(result, isNot(contains('语音消息')));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'image preview resolves to English l10n string',
      () {
        final result = MessagePreviewResolver.resolve(
          attachments: const [
            MessageAttachment(
              name: 'photo.jpg',
              type: 'image/jpeg',
              url: 'https://example.com/photo.jpg',
              id: 'att-1',
            ),
          ],
        );
        expect(result, equals(l10n.previewImage));
        expect(result, isNot(equals('图片')));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'video preview resolves to English l10n string',
      () {
        final result = MessagePreviewResolver.resolve(
          attachments: const [
            MessageAttachment(
              name: 'clip.mp4',
              type: 'video/mp4',
              url: 'https://example.com/clip.mp4',
              id: 'att-1',
            ),
          ],
        );
        expect(result, equals(l10n.previewVideo));
        expect(result, isNot(equals('视频')));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'fallback preview resolves to English l10n string',
      () {
        final result = MessagePreviewResolver.resolve();
        expect(result, equals(l10n.previewFallback));
        expect(result, isNot(equals('新消息')));
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );
  });

  // -----------------------------------------------------------------------
  // INV-I18N-PREVIEW-2: Attachment preview uses l10n template
  // -----------------------------------------------------------------------
  group('INV-I18N-PREVIEW-2: attachment preview l10n template', () {
    test(
      'generic attachment preview uses l10n template with filename',
      () {
        final result = MessagePreviewResolver.resolve(
          attachments: const [
            MessageAttachment(
              name: 'document.pdf',
              type: 'application/pdf',
              url: 'https://example.com/doc.pdf',
              id: 'att-1',
            ),
          ],
        );
        // Phase B: resolve returns l10n.previewAttachment('document.pdf')
        expect(result, equals(l10n.previewAttachment('document.pdf')),
            reason: 'Attachment preview must use l10n template');
        expect(result, isNot(startsWith('附件')),
            reason: 'Must not use hardcoded Chinese prefix');
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );
  });

  // -----------------------------------------------------------------------
  // INV-I18N-STATUS-1: All 6 displayStatusLabel values use l10n
  // -----------------------------------------------------------------------
  group('INV-I18N-STATUS-1: agent status labels use l10n', () {
    test(
      'all 6 displayStatusLabel values resolve to English l10n strings',
      () {
        final expected = {
          AgentDisplayStatus.thinking: l10n.agentStatusThinking,
          AgentDisplayStatus.working: l10n.agentStatusWorking,
          AgentDisplayStatus.error: l10n.agentStatusError,
          AgentDisplayStatus.online: l10n.agentStatusOnline,
          AgentDisplayStatus.offline: l10n.agentStatusOffline,
          AgentDisplayStatus.stopped: l10n.agentStatusStopped,
        };

        for (final entry in expected.entries) {
          final result = displayStatusLabel(entry.key);
          expect(result, equals(entry.value),
              reason:
                  '${entry.key.name} label must resolve via l10n to "${entry.value}"');
        }
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );

    test(
      'displayStatusLabel does not return hardcoded Chinese',
      () {
        const chineseLabels = ['思考中', '工作中', '错误', '在线', '离线', '已停止'];
        for (final status in AgentDisplayStatus.values) {
          final result = displayStatusLabel(status);
          expect(chineseLabels.contains(result), isFalse,
              reason:
                  '${status.name} must not return hardcoded Chinese "$result"');
        }
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );
  });

  // -----------------------------------------------------------------------
  // INV-I18N-GROUP-1: mergedSummary uses locale-aware separator
  // -----------------------------------------------------------------------
  group('INV-I18N-GROUP-1: mergedSummary locale-aware separator', () {
    test(
      'mergedSummary uses comma separator instead of Chinese 、',
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

        final summary = group.mergedSummary;

        // Must NOT contain Chinese enumeration comma.
        expect(summary, isNot(contains('、')),
            reason: 'mergedSummary must not use Chinese comma 、');

        // Must use locale-aware separator (English: ", ").
        expect(summary, contains(', '),
            reason: 'mergedSummary must use locale-aware comma separator');

        // Status label must be l10n English, not Chinese.
        expect(summary, isNot(contains('思考中')),
            reason: 'Status label must not be hardcoded Chinese');
      },
      skip: 'Phase A: invariant locked — Phase B wires l10n',
    );
  });
}
