// =============================================================================
// #801 — Agents l10n coverage
//
// Phase A tests for agents page + agent form dialog l10n sweep.
//
// Invariants verified:
//   INV-801-PARITY-1: All agents-prefixed keys exist in EN, ZH, and ES
//                     (three-way symmetric parity)
//   INV-801-RENDER-1: AgentsPage renders without crash in ZH locale
//   INV-801-RENDER-2: AgentsPage renders without crash in ES locale
//
// Phase A: tests only — must pass on current impl (before l10n extraction).
// Phase B: adds ARB keys and replaces hardcoded strings.
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-801-PARITY-1: Three-way ARB parity for agents-prefixed keys
  // ---------------------------------------------------------------------------
  group('Agents ARB key parity', () {
    late Map<String, dynamic> enArb;
    late Map<String, dynamic> zhArb;
    late Map<String, dynamic> esArb;

    setUpAll(() {
      final enFile = File('lib/l10n/app_en.arb');
      final zhFile = File('lib/l10n/app_zh.arb');
      final esFile = File('lib/l10n/app_es.arb');
      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');
      expect(zhFile.existsSync(), isTrue, reason: 'app_zh.arb must exist');
      expect(esFile.existsSync(), isTrue, reason: 'app_es.arb must exist');
      enArb = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      zhArb = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      esArb = jsonDecode(esFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test(
        'agents-prefixed keys are symmetric across EN, ZH, and ES '
        '(INV-801-PARITY-1)', () {
      // Extract agents-prefixed message keys from each locale.
      final enAgentsKeys = enArb.keys
          .where((k) => !k.startsWith('@') && k.startsWith('agents'))
          .toSet();
      final zhAgentsKeys = zhArb.keys
          .where((k) => !k.startsWith('@') && k.startsWith('agents'))
          .toSet();
      final esAgentsKeys = esArb.keys
          .where((k) => !k.startsWith('@') && k.startsWith('agents'))
          .toSet();

      // EN ↔ ZH
      final enOnlyVsZh = enAgentsKeys.difference(zhAgentsKeys);
      final zhOnlyVsEn = zhAgentsKeys.difference(enAgentsKeys);
      expect(enOnlyVsZh, isEmpty,
          reason: 'Agents keys in EN but missing in ZH: $enOnlyVsZh');
      expect(zhOnlyVsEn, isEmpty,
          reason: 'Agents keys in ZH but missing in EN: $zhOnlyVsEn');

      // EN ↔ ES
      final enOnlyVsEs = enAgentsKeys.difference(esAgentsKeys);
      final esOnlyVsEn = esAgentsKeys.difference(enAgentsKeys);
      expect(enOnlyVsEs, isEmpty,
          reason: 'Agents keys in EN but missing in ES: $enOnlyVsEs');
      expect(esOnlyVsEn, isEmpty,
          reason: 'Agents keys in ES but missing in EN: $esOnlyVsEn');

      // Identical counts (implies set equality given above).
      expect(enAgentsKeys.length, zhAgentsKeys.length,
          reason: 'EN and ZH agents key counts must match');
      expect(enAgentsKeys.length, esAgentsKeys.length,
          reason: 'EN and ES agents key counts must match');
    });

    test('all agents-prefixed keys have non-empty values in all locales', () {
      final agentsKeys = enArb.keys
          .where((k) => !k.startsWith('@') && k.startsWith('agents'))
          .toList();

      for (final key in agentsKeys) {
        expect((enArb[key] as String).isNotEmpty, isTrue,
            reason: 'EN value for $key must not be empty');
        expect((zhArb[key] as String).isNotEmpty, isTrue,
            reason: 'ZH value for $key must not be empty');
        expect((esArb[key] as String).isNotEmpty, isTrue,
            reason: 'ES value for $key must not be empty');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // INV-801-RENDER-1: AgentsPage renders in ZH locale
  // ---------------------------------------------------------------------------
  group('Agents page locale render', () {
    testWidgets(
      'AgentsPage renders without crash in ZH locale (INV-801-RENDER-1)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsStoreProvider.overrideWith(() => _FakeAgentsStore()),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const AgentsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Page should build — find the empty state or agent list.
        expect(find.byKey(const ValueKey('agents-empty')), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // INV-801-RENDER-2: AgentsPage renders in ES locale
    // -------------------------------------------------------------------------
    testWidgets(
      'AgentsPage renders without crash in ES locale (INV-801-RENDER-2)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsStoreProvider.overrideWith(() => _FakeAgentsStore()),
            ],
            child: MaterialApp(
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const AgentsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('agents-empty')), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // INV-801-RENDER-3: AgentsPage with items renders in ZH locale
    // -------------------------------------------------------------------------
    testWidgets(
      'AgentsPage with agents renders without crash in ZH locale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsStoreProvider
                  .overrideWith(() => _FakeAgentsStoreWithItems()),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const AgentsPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Should find agent labels rendered.
        expect(find.text('Test Agent'), findsOneWidget);
      },
    );
  });
}

// -- Fakes --------------------------------------------------------------------

class _FakeAgentsStore extends AgentsStore {
  @override
  AgentsState build() => const AgentsState(
        status: AgentsStatus.success,
        items: [],
      );

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {}
}

class _FakeAgentsStoreWithItems extends AgentsStore {
  @override
  AgentsState build() => const AgentsState(
        status: AgentsStatus.success,
        items: [
          AgentItem(
            id: 'agent-1',
            name: 'test-agent',
            displayName: 'Test Agent',
            model: 'claude-sonnet',
            runtime: 'claude_code',
            status: 'active',
            activity: 'online',
          ),
        ],
      );

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {}
}
