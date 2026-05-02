import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Accumulates resolved thread channel IDs within the session.
///
/// Used by realtime bindings to distinguish thread channels from
/// DM conversations, preventing phantom DM materialization when
/// a `message:new` event arrives for a thread channel.
final knownThreadChannelIdsProvider =
    StateProvider<Set<String>>((ref) => const {});
