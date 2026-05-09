String? resolveDirectMessageTitle(Object? payload) {
  final map = _readOptionalMap(payload);
  if (map == null) {
    return null;
  }

  return _firstPresentString(
        map,
        fields: const [
          'displayName',
          'peerDisplayName',
          'name',
          'peerName',
          'title',
          'senderName',
        ],
      ) ??
      _firstNestedIdentityName(
        map,
        fields: const [
          'participant',
          'peer',
          'peerUser',
          'user',
          'sender',
          'member',
        ],
      );
}

String? resolveConversationSenderName(Object? payload) {
  final map = _readOptionalMap(payload);
  if (map == null) {
    return null;
  }

  return _firstPresentString(
        map,
        fields: const [
          'senderName',
          'displayName',
          'name',
          'peerDisplayName',
          'peerName',
        ],
      ) ??
      _firstNestedIdentityName(
        map,
        fields: const ['sender', 'user', 'member', 'participant', 'peer'],
      );
}

String? _firstNestedIdentityName(
  Map<String, dynamic> payload, {
  required List<String> fields,
}) {
  for (final field in fields) {
    final nested = _readOptionalMap(payload[field]);
    if (nested == null) {
      continue;
    }

    final name = _firstPresentString(
      nested,
      fields: const ['displayName', 'name', 'title', 'senderName'],
    );
    if (name != null) {
      return name;
    }
  }

  return null;
}

String? _firstPresentString(
  Map<String, dynamic> payload, {
  required List<String> fields,
}) {
  for (final field in fields) {
    final value = _readOptionalString(payload[field]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

Map<String, dynamic>? _readOptionalMap(Object? payload) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  return null;
}

/// Extracts the peer's user/agent ID from a DM payload.
///
/// Tries common field names: `peerId`, `peerUserId`, `peerAgentId`,
/// or nested identity objects with an `id` field.
String? resolveDirectMessagePeerId(Object? payload) {
  final map = _readOptionalMap(payload);
  if (map == null) return null;

  // Try direct ID fields.
  final directId = _firstPresentString(
    map,
    fields: const ['peerId', 'peerUserId', 'peerAgentId', 'participantId'],
  );
  if (directId != null) return directId;

  // Try nested identity objects with an 'id' field.
  for (final field in const ['peer', 'peerUser', 'participant']) {
    final nested = _readOptionalMap(map[field]);
    if (nested == null) continue;
    final id = _readOptionalString(nested['id']);
    if (id != null) return id;
  }

  return null;
}

String? _readOptionalString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}
