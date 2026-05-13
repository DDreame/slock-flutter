import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/announcements/application/announcement_store.dart';

/// Dismissible banner showing the first active announcement at the top of the
/// app (INV-ANNOUNCE-1). Handles dismiss on tap (INV-ANNOUNCE-2).
class AnnouncementBanner extends ConsumerWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(announcementStoreProvider);

    // Trigger load on every build so the banner self-populates after
    // provider creation or server-switch rebuild. ensureLoaded() is a
    // no-op when already loading or loaded (INV-ANNOUNCE-1).
    ref.read(announcementStoreProvider.notifier).ensureLoaded();

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
