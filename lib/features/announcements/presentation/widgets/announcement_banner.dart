import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/announcements/application/announcement_store.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Dismissible banner showing the first active announcement at the top of the
/// app (INV-ANNOUNCE-1). Handles dismiss on tap (INV-ANNOUNCE-2).
///
/// Uses a [ConsumerStatefulWidget] so loading is triggered from lifecycle
/// callbacks (post-frame in initState + ref.listen for server-switch), keeping
/// [build] read-only with no synchronous state mutations.
class AnnouncementBanner extends ConsumerStatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  ConsumerState<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends ConsumerState<AnnouncementBanner> {
  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  /// Schedules [AnnouncementStore.ensureLoaded] via post-frame callback so
  /// the load never runs during the widget build phase.
  void _scheduleLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(announcementStoreProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementStoreProvider);

    // Re-trigger load when store resets to initial (e.g. server switch).
    // ref.listen callbacks fire post-build, so ensureLoaded() is safe here.
    ref.listen(
      announcementStoreProvider.select((s) => s.status),
      (prev, next) {
        if (next == AnnouncementStatus.initial) {
          _scheduleLoad();
        }
      },
    );

    if (state.status != AnnouncementStatus.success ||
        state.announcements.isEmpty) {
      return const SizedBox.shrink();
    }

    final announcement = state.announcements.first;
    final theme = Theme.of(context);

    return Material(
      key: ValueKey('announcement-banner-${announcement.id}'),
      color: theme.colorScheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                color: theme.colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      announcement.title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (announcement.body != null &&
                        announcement.body!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          announcement.body!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (announcement.dismissible)
                IconButton(
                  key: const ValueKey('announcement-dismiss'),
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  tooltip: context.l10n.dismissAnnouncementTooltip,
                  onPressed: () {
                    ref
                        .read(announcementStoreProvider.notifier)
                        .dismiss(announcement.id);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
