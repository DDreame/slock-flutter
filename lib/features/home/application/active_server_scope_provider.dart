import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

final activeServerScopeIdProvider = Provider<ServerScopeId?>((ref) {
  // INV-ACTIVE-SERVER-SCOPE-SELECT-1: Only consume selectedServerId.
  // Documents contract and future-proofs against state expansion.
  final selectedId = ref.watch(
    serverSelectionStoreProvider.select((s) => s.selectedServerId),
  );
  return selectedId != null ? ServerScopeId(selectedId) : null;
});
