import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agent_display_status.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  AgentItem makeAgent({
    String status = 'active',
    String activity = 'online',
  }) {
    return AgentItem(
      id: 'a1',
      name: 'Agent1',
      model: 'claude',
      runtime: 'claude-code',
      status: status,
      activity: activity,
    );
  }

  group('AgentDisplayStatus enum', () {
    test('has 6 values in priority order', () {
      expect(AgentDisplayStatus.values.length, 6);
      expect(AgentDisplayStatus.values[0], AgentDisplayStatus.thinking);
      expect(AgentDisplayStatus.values[1], AgentDisplayStatus.working);
      expect(AgentDisplayStatus.values[2], AgentDisplayStatus.error);
      expect(AgentDisplayStatus.values[3], AgentDisplayStatus.online);
      expect(AgentDisplayStatus.values[4], AgentDisplayStatus.offline);
      expect(AgentDisplayStatus.values[5], AgentDisplayStatus.stopped);
    });
  });

  group('resolveDisplayStatus', () {
    test('active + thinking → thinking', () {
      expect(
        resolveDisplayStatus(makeAgent(activity: 'thinking')),
        AgentDisplayStatus.thinking,
      );
    });

    test('active + working → working', () {
      expect(
        resolveDisplayStatus(makeAgent(activity: 'working')),
        AgentDisplayStatus.working,
      );
    });

    test('active + error → error', () {
      expect(
        resolveDisplayStatus(makeAgent(activity: 'error')),
        AgentDisplayStatus.error,
      );
    });

    test('active + online → online', () {
      expect(
        resolveDisplayStatus(makeAgent(activity: 'online')),
        AgentDisplayStatus.online,
      );
    });

    test('active + offline → offline', () {
      expect(
        resolveDisplayStatus(makeAgent(activity: 'offline')),
        AgentDisplayStatus.offline,
      );
    });

    test('active + unknown activity → offline', () {
      expect(
        resolveDisplayStatus(makeAgent(activity: 'something-unknown')),
        AgentDisplayStatus.offline,
      );
    });

    test('stopped agent always resolves to stopped regardless of activity', () {
      for (final activity in [
        'thinking',
        'working',
        'error',
        'online',
        'offline',
      ]) {
        expect(
          resolveDisplayStatus(
              makeAgent(status: 'stopped', activity: activity)),
          AgentDisplayStatus.stopped,
          reason: 'Stopped agent with stale activity "$activity" '
              'should resolve to stopped',
        );
      }
    });

    test('unknown status with valid activity → resolved by activity', () {
      expect(
        resolveDisplayStatus(makeAgent(status: 'unknown', activity: 'working')),
        AgentDisplayStatus.working,
      );
    });
  });

  group('displayStatusPriority', () {
    test('thinking has highest priority (0)', () {
      expect(displayStatusPriority(AgentDisplayStatus.thinking), 0);
    });

    test('stopped has lowest priority (5)', () {
      expect(displayStatusPriority(AgentDisplayStatus.stopped), 5);
    });

    test('priority order matches enum index', () {
      for (var i = 0; i < AgentDisplayStatus.values.length; i++) {
        expect(
          displayStatusPriority(AgentDisplayStatus.values[i]),
          i,
          reason: '${AgentDisplayStatus.values[i]} should have priority $i',
        );
      }
    });
  });

  group('displayStatusLabel', () {
    test('thinking → 思考中', () {
      expect(
          displayStatusLabel(AgentDisplayStatus.thinking, l10n: l10n), '思考中');
    });

    test('working → 工作中', () {
      expect(displayStatusLabel(AgentDisplayStatus.working, l10n: l10n), '工作中');
    });

    test('online → 在线', () {
      expect(displayStatusLabel(AgentDisplayStatus.online, l10n: l10n), '在线');
    });

    test('error → 错误', () {
      expect(displayStatusLabel(AgentDisplayStatus.error, l10n: l10n), '错误');
    });

    test('offline → 离线', () {
      expect(displayStatusLabel(AgentDisplayStatus.offline, l10n: l10n), '离线');
    });

    test('stopped → 已停止', () {
      expect(displayStatusLabel(AgentDisplayStatus.stopped, l10n: l10n), '已停止');
    });
  });
}
