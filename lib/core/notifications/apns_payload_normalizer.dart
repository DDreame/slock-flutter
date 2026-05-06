/// Normalizes a raw APNs payload into the flat format expected by Dart routing.
///
/// This mirrors the native Swift normalization in AppDelegate.swift and serves
/// as both documentation and a defensive fallback. The native side performs
/// this normalization before payloads reach Dart, but this function can be
/// used in tests to validate the expected contract.
///
/// Standard APNs structure:
/// ```json
/// {
///   "aps": { "alert": { "title": "...", "body": "..." } },
///   "type": "channel",
///   "serverId": "...",
///   "channelId": "..."
/// }
/// ```
///
/// Thread payloads use parent identity:
/// ```json
/// {
///   "aps": { "alert": { "title": "...", "body": "..." } },
///   "type": "thread",
///   "serverId": "...",
///   "parentChannelId": "channel-1",
///   "parentMessageId": "msg-123"
/// }
/// ```
///
/// Output: flat `Map<String, dynamic>` with `title`, `body`, `type`,
/// `serverId`, `channelId`, `threadId`, `messageId`, `senderId`, etc.
Map<String, dynamic>? normalizeApnsPayload(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) return null;

  final result = <String, dynamic>{};

  // Extract title/body from aps.alert (dict or string form)
  final aps = raw['aps'];
  if (aps is Map) {
    final alert = aps['alert'];
    if (alert is Map) {
      if (alert['title'] is String) {
        result['title'] = alert['title'];
      }
      if (alert['body'] is String) {
        result['body'] = alert['body'];
      }
    } else if (alert is String) {
      result['body'] = alert;
    }
  }

  // Flatten all non-aps top-level keys
  for (final entry in raw.entries) {
    if (entry.key == 'aps' || entry.key == 'slock.localRepost') {
      continue;
    }
    result[entry.key] = entry.value;
  }

  // Thread parent identity remapping:
  // Backend sends parentChannelId + parentMessageId for thread payloads.
  // Dart routing expects flat channelId + threadId.
  if (result['type'] == 'thread') {
    final parentChannelId = result['parentChannelId'] as String?;
    final parentMessageId = result['parentMessageId'] as String?;
    if (parentChannelId != null) {
      result['channelId'] = parentChannelId;
      result.remove('parentChannelId');
    }
    if (parentMessageId != null) {
      result['threadId'] = parentMessageId;
      result.remove('parentMessageId');
    }
  }

  // Preserve title/body from top-level if not already set from aps.alert
  if (result['title'] == null && raw['title'] is String) {
    result['title'] = raw['title'];
  }
  if (result['body'] == null && raw['body'] is String) {
    result['body'] = raw['body'];
  }

  // Require type field for validity
  if (result['type'] is! String) return null;

  return result;
}
