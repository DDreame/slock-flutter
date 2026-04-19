import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

final activeServerScopeIdProvider = Provider<ServerScopeId?>((ref) {
  final selectedId = ref.watch(serverSelectionStoreProvider).selectedServerId;
  return selectedId != null ? ServerScopeId(selectedId) : null;
});
