import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/announcements/application/dismissed_announcement_ids.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';
import 'package:slock_app/features/announcements/data/announcement_repository.dart';

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
}

final announcementStoreProvider =
    AutoDisposeNotifierProvider<AnnouncementStore, AnnouncementState>(
  AnnouncementStore.new,
);

class AnnouncementStore extends AutoDisposeNotifier<AnnouncementState> {
  @override
  AnnouncementState build() {
    return const AnnouncementState();
  }

  Future<void> ensureLoaded() async {
    if (state.status == AnnouncementStatus.loading ||
        state.status == AnnouncementStatus.success) {
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
  void addAnnouncement(Announcement announcement) {
    final dismissed = ref.read(dismissedAnnouncementIdsProvider);
    if (dismissed.contains(announcement.id)) return;

    final exists = state.announcements.any((a) => a.id == announcement.id);
    if (exists) return;

    state = state.copyWith(
      announcements: [...state.announcements, announcement],
    );
  }
}
