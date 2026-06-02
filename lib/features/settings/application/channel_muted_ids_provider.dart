/// Application-layer re-export of [channelMutedIdsProvider] and
/// [ChannelNotificationPreferenceRepository] (for static utilities).
///
/// Keeps the presentation layer decoupled from the data layer — presentation
/// files should import this file instead of the data-layer provider directly.
library;

export 'package:slock_app/features/settings/data/channel_notification_preference.dart'
    show channelMutedIdsProvider, ChannelNotificationPreferenceRepository;
