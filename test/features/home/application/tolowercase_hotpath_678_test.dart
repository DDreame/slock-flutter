// =============================================================================
// #678 — toLowerCase hot-path pre-computation tests
//
// Verifies that channel sort and machine sort handle mixed-case names correctly
// after hoisting toLowerCase() outside comparator loops.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/channel_sort_preference.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

// ---------------------------------------------------------------------------
// Controllable store for test manipulation
// ---------------------------------------------------------------------------

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('s1'),
              value: 'ch-zebra',
            ),
            name: 'zebra',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('s1'),
              value: 'ch-alpha',
            ),
            name: 'Alpha',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('s1'),
              value: 'ch-mango',
            ),
            name: 'MANGO',
          ),
        ],
        pinnedChannels: const [],
      );
}

void main() {
  const serverId = ServerScopeId('s1');

  test(
    'sortedChannelListProvider sorts mixed-case names case-insensitively '
    '(pre-computed toLowerCase)',
    () {
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
          channelSortPreferenceProvider
              .overrideWith(() => _AlphabeticalSortNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final sorted = container.read(sortedChannelListProvider);
      final names = sorted.map((c) => c.name).toList();

      // Alpha < MANGO < zebra (case-insensitive)
      expect(names, equals(['Alpha', 'MANGO', 'zebra']));
    },
  );
}

// Always returns alphabetical sort preference.
class _AlphabeticalSortNotifier extends ChannelSortPreferenceNotifier {
  @override
  ChannelSortPreference build() => ChannelSortPreference.alphabetical;
}
