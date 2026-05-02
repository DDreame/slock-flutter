import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Accumulates resolved thread channel IDs within the session,
/// qualified by server ID to prevent cross-server collisions.
///
/// Keys are formatted as `serverId/threadChannelId`. Used by
/// realtime bindings to distinguish thread channels from DM
/// conversations, preventing phantom DM materialization when
/// a `message:new` event arrives for a thread channel.
///
/// Cleared on logout via [channelUnreadSessionBindingProvider].
final knownThreadChannelIdsProvider =
    StateProvider<Set<String>>((ref) => const {});

/// Builds a qualified key for the known thread channel IDs set.
String threadChannelKey(String serverId, String threadChannelId) =>
    '$serverId/$threadChannelId';
