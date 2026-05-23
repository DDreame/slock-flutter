import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/announcements/application/dismissed_announcement_ids.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';
import 'package:slock_app/features/announcements/data/announcement_repository.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

enum AnnouncementStatus { initial, loading, success, failure }

@immutable
class AnnouncementState {
  const AnnouncementState({
    this.status = AnnouncementStatus.initial,
    this.announcements = const [],
    this.failure,
  });

  final AnnouncementStatus status;
  final List<Announcement> announcements;
  final AppFailure? failure;

  AnnouncementState copyWith({
    AnnouncementStatus? status,
    List<Announcement>? announcements,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return AnnouncementState(
      status: status ?? this.status,
      announcements: announcements ?? this.announcements,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(announcements, other.announcements) &&
          failure == other.failure;

  @override
  int get hashCode =>
      Object.hash(status, Object.hashAll(announcements), failure);
}

/// App-level (keepAlive) announcement store. Watches
/// [activeServerScopeIdProvider] so switching servers rebuilds the
/// store with fresh state (INV-ANNOUNCE-1 / INV-ANNOUNCE-3).
///
/// Load is triggered by [AnnouncementBanner] from a post-frame
/// callback in initState — never during widget build.
final announcementStoreProvider =
    NotifierProvider<AnnouncementStore, AnnouncementState>(
  AnnouncementStore.new,
);

class AnnouncementStore extends Notifier<AnnouncementState> {
  @override
  bool updateShouldNotify(
    AnnouncementState previous,
    AnnouncementState next,
  ) =>
      previous != next;

  @override
  AnnouncementState build() {
    // Watch server scope so a server switch triggers rebuild → fresh state.
    ref.watch(activeServerScopeIdProvider);
    return const AnnouncementState();
  }

  /// Triggers [load] if not already loading, loaded, or failed. Called by
  /// [AnnouncementBanner] on every build so the banner self-populates.
  /// Treats [AnnouncementStatus.failure] as terminal to prevent unbounded
  /// retry loops on persistent backend errors.
  Future<void> ensureLoaded() async {
    if (state.status != AnnouncementStatus.initial) {
      return;
    }
    await load();
  }

  /// Loads active announcements from the API, filtering out dismissed ones
  /// (INV-ANNOUNCE-1 + INV-ANNOUNCE-3).
  Future<void> load() async {
    state = state.copyWith(
      status: AnnouncementStatus.loading,
      clearFailure: true,
    );

    try {
      final serverId = ref.read(activeServerScopeIdProvider);
      if (serverId == null) {
        state = state.copyWith(
          status: AnnouncementStatus.success,
          announcements: const [],
        );
        return;
      }

      final repo = ref.read(announcementRepositoryProvider);
      final all = await repo.getActive(serverId);

      // Guard: server may have switched during the await.
      if (ref.read(activeServerScopeIdProvider) != serverId) return;

      final dismissed = ref.read(dismissedAnnouncementIdsProvider);
      final filtered = all.where((a) => !dismissed.contains(a.id)).toList();

      state = state.copyWith(
        status: AnnouncementStatus.success,
        announcements: filtered,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: AnnouncementStatus.failure,
        failure: failure,
      );
    } catch (error, stackTrace) {
      _captureUnexpectedError(error, stackTrace);
      state = state.copyWith(
        status: AnnouncementStatus.failure,
        failure: UnknownFailure(
          message: 'Failed to load announcements.',
          causeType: error.runtimeType.toString(),
        ),
      );
    }
  }

  /// Dismisses an announcement — removes from list, persists, and calls API
  /// (INV-ANNOUNCE-2 + INV-ANNOUNCE-3).
  Future<void> dismiss(String announcementId) async {
    // Optimistically remove from local list.
    final updated =
        state.announcements.where((a) => a.id != announcementId).toList();
    state = state.copyWith(announcements: updated);

    // Persist dismissal locally.
    ref.read(dismissedAnnouncementIdsProvider.notifier).dismiss(announcementId);

    // Fire-and-forget API call.
    try {
      final serverId = ref.read(activeServerScopeIdProvider);
      if (serverId != null) {
        await ref.read(announcementRepositoryProvider).dismiss(
              serverId,
              announcementId: announcementId,
            );
      }
    } catch (_) {
      // Dismissal is already persisted locally; API failure is non-critical.
    }
  }

  /// Adds a new announcement from a WebSocket event (INV-ANNOUNCE-4).
  /// Skips if already dismissed or already in the list.
  /// Promotes status to [AnnouncementStatus.success] so the banner renders
  /// even if the initial API load hasn't completed yet.
  void addAnnouncement(Announcement announcement) {
    final dismissed = ref.read(dismissedAnnouncementIdsProvider);
    if (dismissed.contains(announcement.id)) return;

    final exists = state.announcements.any((a) => a.id == announcement.id);
    if (exists) return;

    state = state.copyWith(
      status: AnnouncementStatus.success,
      announcements: [...state.announcements, announcement],
    );
  }

  void _captureUnexpectedError(Object error, StackTrace stackTrace) {
    try {
      ref.read(diagnosticsCollectorProvider).error(
        'AnnouncementStore',
        'load failed: $error',
        metadata: {'stackTrace': stackTrace.toString()},
      );
    } catch (_) {}
  }
}
