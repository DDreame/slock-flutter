import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

final serverListStoreProvider =
    NotifierProvider<ServerListStore, ServerListState>(ServerListStore.new);

class ServerListStore extends Notifier<ServerListState> {
  @override
  ServerListState build() {
    Future.microtask(() {
      if (state.status == ServerListStatus.initial) {
        load();
      }
    });
    return const ServerListState();
  }

  Future<void> load() async {
    state = state.copyWith(
      status: ServerListStatus.loading,
      clearFailure: true,
    );

    try {
      final servers =
          await ref.read(serverListRepositoryProvider).loadServers();
      state = state.copyWith(
        status: ServerListStatus.success,
        servers: servers,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: ServerListStatus.failure,
        failure: failure,
      );
    }
  }

  Future<void> retry() => load();

  Future<ServerSummary> createServer(String name) async {
    final normalizedName = name.trim();
    final slug = _buildWorkspaceSlug(normalizedName);

    state = state.copyWith(isCreating: true, clearFailure: true);

    try {
      final repo = ref.read(serverListRepositoryProvider);
      final server = await repo.createServer(name: normalizedName, slug: slug);
      final servers = [...state.servers, server];
      state = state.copyWith(
        status: ServerListStatus.success,
        servers: servers,
        isCreating: false,
        clearFailure: true,
      );
      await _cohereSelection(servers: servers, preferredServerId: server.id);
      return server;
    } on AppFailure catch (failure) {
      state = state.copyWith(isCreating: false, failure: failure);
      rethrow;
    }
  }

  Future<ServerSummary?> renameServer(String serverId, String name) async {
    final normalizedName = name.trim();
    state = state.copyWith(
      savingServerIds: {...state.savingServerIds, serverId},
      clearFailure: true,
    );

    try {
      final repo = ref.read(serverListRepositoryProvider);
      final updatedName = await repo.renameServer(
        serverId,
        name: normalizedName,
      );
      ServerSummary? updatedServer;
      final servers = state.servers.map((server) {
        if (server.id != serverId) {
          return server;
        }
        updatedServer = server.copyWith(name: updatedName);
        return updatedServer!;
      }).toList(growable: false);
      state = state.copyWith(
        status: ServerListStatus.success,
        servers: servers,
        savingServerIds: {...state.savingServerIds}..remove(serverId),
        clearFailure: true,
      );
      return updatedServer;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        savingServerIds: {...state.savingServerIds}..remove(serverId),
        failure: failure,
      );
      rethrow;
    }
  }

  Future<void> deleteServer(String serverId) async {
    state = state.copyWith(
      deletingServerIds: {...state.deletingServerIds, serverId},
      clearFailure: true,
    );

    try {
      final repo = ref.read(serverListRepositoryProvider);
      await repo.deleteServer(serverId);
      final servers = state.servers
          .where((server) => server.id != serverId)
          .toList(growable: false);
      state = state.copyWith(
        status: ServerListStatus.success,
        servers: servers,
        deletingServerIds: {...state.deletingServerIds}..remove(serverId),
        clearFailure: true,
      );
      await _cohereSelection(servers: servers);
    } on AppFailure catch (failure) {
      state = state.copyWith(
        deletingServerIds: {...state.deletingServerIds}..remove(serverId),
        failure: failure,
      );
      rethrow;
    }
  }

  Future<void> leaveServer(String serverId) async {
    state = state.copyWith(
      leavingServerIds: {...state.leavingServerIds, serverId},
      clearFailure: true,
    );

    try {
      final repo = ref.read(serverListRepositoryProvider);
      await repo.leaveServer(serverId);
      final servers = state.servers
          .where((server) => server.id != serverId)
          .toList(growable: false);
      state = state.copyWith(
        status: ServerListStatus.success,
        servers: servers,
        leavingServerIds: {...state.leavingServerIds}..remove(serverId),
        clearFailure: true,
      );
      await _cohereSelection(servers: servers);
    } on AppFailure catch (failure) {
      state = state.copyWith(
        leavingServerIds: {...state.leavingServerIds}..remove(serverId),
        failure: failure,
      );
      rethrow;
    }
  }

  Future<String> acceptInvite(String rawInput) async {
    final token = _normalizeInviteToken(rawInput);

    state = state.copyWith(isJoiningInvite: true, clearFailure: true);

    try {
      final repo = ref.read(serverListRepositoryProvider);
      final serverId = await repo.acceptInvite(token);
      final servers = await repo.loadServers();
      state = state.copyWith(
        status: ServerListStatus.success,
        servers: servers,
        isJoiningInvite: false,
        clearFailure: true,
      );
      await _cohereSelection(servers: servers, preferredServerId: serverId);
      return serverId;
    } on AppFailure catch (failure) {
      state = state.copyWith(isJoiningInvite: false, failure: failure);
      rethrow;
    }
  }

  Future<void> _cohereSelection({
    required List<ServerSummary> servers,
    String? preferredServerId,
  }) async {
    final selectionState = ref.read(serverSelectionStoreProvider);
    final selectionStore = ref.read(serverSelectionStoreProvider.notifier);
    final selectedServerId = selectionState.selectedServerId;

    final nextServerId = _findAvailableServerId(servers, preferredServerId) ??
        _findAvailableServerId(servers, selectedServerId) ??
        (servers.isNotEmpty ? servers.first.id : null);

    if (nextServerId == null) {
      if (selectedServerId != null) {
        await selectionStore.clearSelection();
      }
      return;
    }

    if (nextServerId != selectedServerId) {
      await selectionStore.selectServer(nextServerId);
    }
  }

  String? _findAvailableServerId(
    List<ServerSummary> servers,
    String? serverId,
  ) {
    if (serverId == null) {
      return null;
    }
    return servers.any((server) => server.id == serverId) ? serverId : null;
  }

  String _normalizeInviteToken(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      throw const UnknownFailure(
        message: 'Enter an invite code or link.',
        causeType: 'ValidationError',
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final queryToken = uri.queryParameters['token'];
      if (queryToken != null && queryToken.isNotEmpty) {
        return queryToken;
      }
    }

    final segments = trimmed.split('/').where((segment) => segment.isNotEmpty);
    if (segments.length > 1) {
      return segments.last;
    }

    return trimmed;
  }

  String _buildWorkspaceSlug(String name) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (normalized.isNotEmpty) {
      return normalized;
    }

    final codepointSlug = name
        .trim()
        .runes
        .take(6)
        .map((rune) => rune.toRadixString(16))
        .join('-');
    if (codepointSlug.isNotEmpty) {
      return 'workspace-$codepointSlug';
    }
    throw const UnknownFailure(
      message: 'Enter a workspace name.',
      causeType: 'ValidationError',
    );
  }
}
