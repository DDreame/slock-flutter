// =============================================================================
// #802 Phase A — L10n Sweep: Channels + Servers
//
// Invariants verified:
// 1. channels/servers-prefixed ARB keys are symmetric across EN, ZH, and ES
// 2. All channels/servers-prefixed keys have non-empty values in all locales
// 3. CreateChannelPage renders without crash in ZH locale
// 4. CreateChannelPage renders without crash in ES locale
// 5. ServerSwitcherSheet renders without crash in ZH locale
// 6. WorkspaceSettingsPage renders without crash in ZH locale
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/presentation/page/create_channel_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/page/workspace_settings_page.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_switcher_sheet.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/stores/server_selection/server_selection_state.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeChannelManagementStore extends ChannelManagementStore {
  @override
  ChannelManagementState build() => const ChannelManagementState();
}

class _FakeServerListStore extends ServerListStore {
  @override
  ServerListState build() => const ServerListState(
        status: ServerListStatus.success,
        servers: [],
      );

  @override
  Future<void> retry() async {}
}

class _FakeServerListStoreWithServer extends ServerListStore {
  @override
  ServerListState build() => const ServerListState(
        status: ServerListStatus.success,
        servers: [
          ServerSummary(id: 'test-server', name: 'Test', role: 'owner'),
        ],
      );

  @override
  Future<void> retry() async {}
}

class _FakeServerSelectionStore extends ServerSelectionStore {
  @override
  ServerSelectionState build() => const ServerSelectionState();

  @override
  Future<void> selectServer(String serverId) async {}
}

void main() {
  // ---------------------------------------------------------------------------
  // ARB key parity
  // ---------------------------------------------------------------------------
  group('Channels/Servers ARB key parity', () {
    late Map<String, dynamic> enArb;
    late Map<String, dynamic> zhArb;
    late Map<String, dynamic> esArb;

    setUpAll(() {
      final enFile = File('lib/l10n/app_en.arb');
      final zhFile = File('lib/l10n/app_zh.arb');
      final esFile = File('lib/l10n/app_es.arb');
      expect(enFile.existsSync(), isTrue);
      expect(zhFile.existsSync(), isTrue);
      expect(esFile.existsSync(), isTrue);
      enArb = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      zhArb = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      esArb = jsonDecode(esFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test(
      'channels/servers-prefixed keys are symmetric across EN, ZH, and ES '
      '(INV-802-PARITY-1)',
      () {
        bool isTarget(String k) =>
            k.startsWith('channels') || k.startsWith('servers');

        final enKeys =
            enArb.keys.where((k) => !k.startsWith('@') && isTarget(k)).toSet();
        final zhKeys =
            zhArb.keys.where((k) => !k.startsWith('@') && isTarget(k)).toSet();
        final esKeys =
            esArb.keys.where((k) => !k.startsWith('@') && isTarget(k)).toSet();

        final enOnlyZh = enKeys.difference(zhKeys);
        final zhOnlyEn = zhKeys.difference(enKeys);
        final enOnlyEs = enKeys.difference(esKeys);
        final esOnlyEn = esKeys.difference(enKeys);

        expect(enOnlyZh, isEmpty, reason: 'EN keys missing in ZH: $enOnlyZh');
        expect(zhOnlyEn, isEmpty, reason: 'ZH keys missing in EN: $zhOnlyEn');
        expect(enOnlyEs, isEmpty, reason: 'EN keys missing in ES: $enOnlyEs');
        expect(esOnlyEn, isEmpty, reason: 'ES keys missing in EN: $esOnlyEn');
      },
    );

    test(
      'all channels/servers-prefixed keys have non-empty values in all locales',
      () {
        bool isTarget(String k) =>
            k.startsWith('channels') || k.startsWith('servers');

        final enKeys =
            enArb.keys.where((k) => !k.startsWith('@') && isTarget(k));

        for (final key in enKeys) {
          expect((enArb[key] as String?)?.isNotEmpty, isTrue,
              reason: 'EN key "$key" is empty');
          expect((zhArb[key] as String?)?.isNotEmpty, isTrue,
              reason: 'ZH key "$key" is empty');
          expect((esArb[key] as String?)?.isNotEmpty, isTrue,
              reason: 'ES key "$key" is empty');
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Locale render — CreateChannelPage
  // ---------------------------------------------------------------------------
  group('CreateChannelPage locale render', () {
    testWidgets(
      'CreateChannelPage renders without crash in ZH locale (INV-802-RENDER-1)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              channelManagementStoreProvider
                  .overrideWith(_FakeChannelManagementStore.new),
              activeServerScopeIdProvider
                  .overrideWith((_) => const ServerScopeId('test-server')),
            ],
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: CreateChannelPage(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CreateChannelPage renders without crash in ES locale (INV-802-RENDER-2)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              channelManagementStoreProvider
                  .overrideWith(_FakeChannelManagementStore.new),
              activeServerScopeIdProvider
                  .overrideWith((_) => const ServerScopeId('test-server')),
            ],
            child: const MaterialApp(
              locale: Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: CreateChannelPage(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Locale render — ServerSwitcherSheet
  // ---------------------------------------------------------------------------
  group('ServerSwitcherSheet locale render', () {
    testWidgets(
      'ServerSwitcherSheet renders without crash in ZH locale '
      '(INV-802-RENDER-3)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              serverListStoreProvider.overrideWith(_FakeServerListStore.new),
              activeServerScopeIdProvider.overrideWith((_) => null),
              serverSelectionStoreProvider
                  .overrideWith(_FakeServerSelectionStore.new),
            ],
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: ServerSwitcherSheet()),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Locale render — WorkspaceSettingsPage
  // ---------------------------------------------------------------------------
  group('WorkspaceSettingsPage locale render', () {
    testWidgets(
      'WorkspaceSettingsPage renders without crash in ZH locale '
      '(INV-802-RENDER-4)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              serverListStoreProvider
                  .overrideWith(_FakeServerListStoreWithServer.new),
            ],
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: WorkspaceSettingsPage(serverId: 'test-server'),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
