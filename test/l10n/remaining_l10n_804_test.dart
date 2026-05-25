// =============================================================================
// #804 Phase A — L10n Sweep: Remaining (Final Batch)
//
// Invariants verified:
// 1. FULL ARB key parity: total EN == ZH == ES (no missing keys anywhere)
// 2. BillingPage renders without crash in ZH locale
// 3. ThreadsPage renders without crash in ZH locale
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/presentation/page/billing_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/presentation/page/threads_page.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeBillingStore extends BillingStore {
  @override
  BillingState build() => const BillingState(
        status: BillingStatus.success,
        hasActiveServerScope: true,
      );

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {}
}

class _FakeThreadsInboxStore extends ThreadsInboxStore {
  @override
  ThreadsInboxState build() => const ThreadsInboxState(
        serverId: ServerScopeId('srv-1'),
        status: ThreadsInboxStatus.success,
        items: [],
      );

  @override
  Future<void> load() async {}

  @override
  Future<void> markDone(ThreadInboxItem item) async {}
}

void main() {
  // ---------------------------------------------------------------------------
  // Full ARB key parity (total count)
  // ---------------------------------------------------------------------------
  group('Full ARB key parity (final sweep)', () {
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
      'total non-metadata EN keys == ZH keys == ES keys (INV-804-PARITY-FULL)',
      () {
        final enKeys = enArb.keys.where((k) => !k.startsWith('@')).toSet();
        final zhKeys = zhArb.keys.where((k) => !k.startsWith('@')).toSet();
        final esKeys = esArb.keys.where((k) => !k.startsWith('@')).toSet();

        final enOnlyZh = enKeys.difference(zhKeys);
        final zhOnlyEn = zhKeys.difference(enKeys);
        final enOnlyEs = enKeys.difference(esKeys);
        final esOnlyEn = esKeys.difference(enKeys);

        expect(enOnlyZh, isEmpty, reason: 'EN keys missing from ZH: $enOnlyZh');
        expect(zhOnlyEn, isEmpty, reason: 'ZH keys missing from EN: $zhOnlyEn');
        expect(enOnlyEs, isEmpty, reason: 'EN keys missing from ES: $enOnlyEs');
        expect(esOnlyEn, isEmpty, reason: 'ES keys missing from EN: $esOnlyEn');
      },
    );

    test(
      'all non-metadata keys have non-empty values',
      () {
        for (final entry in enArb.entries) {
          if (entry.key.startsWith('@') || entry.key == '@@locale') continue;
          expect(entry.value, isNotEmpty,
              reason: 'EN key "${entry.key}" is empty');
        }
        for (final entry in zhArb.entries) {
          if (entry.key.startsWith('@') || entry.key == '@@locale') continue;
          expect(entry.value, isNotEmpty,
              reason: 'ZH key "${entry.key}" is empty');
        }
        for (final entry in esArb.entries) {
          if (entry.key.startsWith('@') || entry.key == '@@locale') continue;
          expect(entry.value, isNotEmpty,
              reason: 'ES key "${entry.key}" is empty');
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Locale render — BillingPage
  // ---------------------------------------------------------------------------
  group('BillingPage locale render', () {
    testWidgets(
      'BillingPage renders without crash in ZH locale (INV-804-RENDER-1)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              billingStoreProvider.overrideWith(_FakeBillingStore.new),
              activeServerScopeIdProvider
                  .overrideWithValue(const ServerScopeId('srv-1')),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const BillingPage(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Locale render — ThreadsPage
  // ---------------------------------------------------------------------------
  group('ThreadsPage locale render', () {
    testWidgets(
      'ThreadsPage renders without crash in ZH locale (INV-804-RENDER-2)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              threadsInboxStoreProvider
                  .overrideWith(_FakeThreadsInboxStore.new),
              activeServerScopeIdProvider
                  .overrideWithValue(const ServerScopeId('srv-1')),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ThreadsPage(serverId: 'srv-1'),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
