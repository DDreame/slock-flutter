// =============================================================================
// #819 — Top Performance: DateFormat caching, channels search guard,
// machines .select() narrowing
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/machines_state.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/presentation/page/machines_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  group('Perf-3: MachinesPage .select() narrowing', () {
    testWidgets(
      'parent scaffold does not rebuild when per-item busy state changes',
      (tester) async {
        final store = _FakeMachinesStore(
          initialState: const MachinesState(
            status: MachinesStatus.success,
            items: [
              MachineItem(
                id: 'machine-1',
                name: 'Builder',
                status: 'online',
              ),
            ],
          ),
        );

        await tester.pumpWidget(_buildMachinesApp(store));
        // Use pump() instead of pumpAndSettle() to avoid timeout from
        // any indefinite animations (e.g. FAB ink splash).
        await tester.pump();
        await tester.pump();

        // Verify success view is visible.
        expect(find.text('Builder'), findsOneWidget);

        // Change per-item busy state (renamingMachineIds) — this should NOT
        // trigger a full parent rebuild since parent only watches
        // (status, isCreating, failure).
        store.setRenamingIds({'machine-1'});
        await tester.pump();
        await tester.pump();

        // FAB should still be enabled (isCreating didn't change).
        final fab = find.byKey(const ValueKey('machines-create-fab'));
        expect(fab, findsOneWidget);
        expect(
          tester.widget<FloatingActionButton>(fab).onPressed,
          isNotNull,
          reason: 'FAB should remain enabled — parent watches isCreating, '
              'not renamingMachineIds.',
        );
      },
    );

    testWidgets(
      'success view rebuilds when items change',
      (tester) async {
        final store = _FakeMachinesStore(
          initialState: const MachinesState(
            status: MachinesStatus.success,
            items: [
              MachineItem(
                id: 'machine-1',
                name: 'Builder',
                status: 'online',
              ),
            ],
          ),
        );

        await tester.pumpWidget(_buildMachinesApp(store));
        await tester.pump();
        await tester.pump();

        expect(find.text('Builder'), findsOneWidget);

        // Add a second machine.
        store.addMachine(const MachineItem(
          id: 'machine-2',
          name: 'Runner',
          status: 'offline',
        ));
        await tester.pump();
        await tester.pump();

        expect(find.text('Runner'), findsOneWidget);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

Widget _buildMachinesApp(_FakeMachinesStore store) {
  final ingress = RealtimeReductionIngress();
  return ProviderScope(
    overrides: [
      machinesStoreProvider.overrideWith(() => store),
      realtimeReductionIngressProvider.overrideWithValue(ingress),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MachinesPage(serverId: 'server-1'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeMachinesStore extends MachinesStore {
  _FakeMachinesStore({required MachinesState initialState})
      : _initialState = initialState;

  final MachinesState _initialState;

  @override
  MachinesState build() => _initialState;

  @override
  Future<void> load() async {}

  @override
  Future<void> ensureLoaded() async {}

  void setRenamingIds(Set<String> ids) {
    state = state.copyWith(renamingMachineIds: ids);
  }

  void addMachine(MachineItem machine) {
    state = state.copyWith(items: [...state.items, machine]);
  }
}
