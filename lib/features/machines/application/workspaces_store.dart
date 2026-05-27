import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/workspaces_state.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';

final currentWorkspacesMachineIdProvider = Provider<String>((ref) {
  throw UnimplementedError(
    'currentWorkspacesMachineIdProvider must be overridden.',
  );
});

final workspacesStoreProvider =
    NotifierProvider.autoDispose<WorkspacesStore, WorkspacesState>(
  WorkspacesStore.new,
  dependencies: [
    currentWorkspacesMachineIdProvider,
    machinesRepositoryProvider
  ],
);

class WorkspacesStore extends AutoDisposeNotifier<WorkspacesState> {
  bool _disposed = false;

  @override
  WorkspacesState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // INV-834: Re-fetch on WebSocket reconnect — data may be stale.
    ref.listen(realtimeServiceProvider.select((s) => s.status), (prev, next) {
      if (prev == RealtimeConnectionStatus.reconnecting &&
          next == RealtimeConnectionStatus.connected) {
        if (state.status == WorkspacesStatus.success) {
          load();
        }
      }
    });

    return const WorkspacesState();
  }

  Future<void> load() async {
    final machineId = ref.read(currentWorkspacesMachineIdProvider);

    state = state.copyWith(
      status: WorkspacesStatus.loading,
      clearFailure: true,
    );

    try {
      final repo = ref.read(machinesRepositoryProvider);
      final workspaces = await repo.loadWorkspaces(machineId);
      if (_disposed) return;
      state = state.copyWith(
        status: WorkspacesStatus.success,
        items: workspaces,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(
        status: WorkspacesStatus.failure,
        failure: failure,
      );
    } catch (e, st) {
      if (_disposed) return;
      _reportUnexpectedError('load', e, st);
      state = state.copyWith(
        status: WorkspacesStatus.failure,
        failure: UnknownFailure(
          message: 'Failed to load workspaces.',
          causeType: e.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    final machineId = ref.read(currentWorkspacesMachineIdProvider);
    // INV-ROLLBACK-829: Snapshot item + index for per-item rollback.
    final removedIndex = state.items.indexWhere((w) => w.id == workspaceId);
    final removedItem = state.items[removedIndex];

    // Optimistic: remove from list and add to deleting set.
    state = state.copyWith(
      items: state.items.where((w) => w.id != workspaceId).toList(),
      deletingWorkspaceIds: {...state.deletingWorkspaceIds, workspaceId},
    );

    try {
      final repo = ref.read(machinesRepositoryProvider);
      await repo.deleteWorkspace(machineId, workspaceId: workspaceId);
      if (_disposed) return;

      // Success — clear deleting flag.
      state = state.copyWith(
        deletingWorkspaceIds:
            state.deletingWorkspaceIds.difference({workspaceId}),
      );
    } on AppFailure {
      if (_disposed) return;
      // Per-item rollback: re-insert at original position.
      _reinsertAtPosition(removedItem, removedIndex);
      state = state.copyWith(
        deletingWorkspaceIds:
            state.deletingWorkspaceIds.difference({workspaceId}),
      );
      rethrow;
    } catch (e, st) {
      if (_disposed) return;
      _reportUnexpectedError('deleteWorkspace', e, st);
      // Per-item rollback: re-insert at original position.
      _reinsertAtPosition(removedItem, removedIndex);
      state = state.copyWith(
        deletingWorkspaceIds:
            state.deletingWorkspaceIds.difference({workspaceId}),
        failure: UnknownFailure(
          message: 'Failed to delete workspace.',
          causeType: e.runtimeType.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Re-inserts [item] at [originalIndex], clamped to the current list length.
  /// Preserves ordering while tolerating concurrent list mutations.
  void _reinsertAtPosition(WorkspaceItem item, int originalIndex) {
    final current = [...state.items];
    final insertAt = originalIndex.clamp(0, current.length);
    current.insert(insertAt, item);
    state = state.copyWith(items: current);
  }

  void _reportUnexpectedError(String method, Object error, StackTrace st) {
    try {
      ref.read(diagnosticsCollectorProvider).error(
        'WorkspacesStore',
        '$method failed: $error',
        metadata: {'stackTrace': st.toString()},
      );
    } catch (_) {}
  }
}
