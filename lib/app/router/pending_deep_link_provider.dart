import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

final _conversationLandingPattern = RegExp(
  r'^/servers/[^/]+/(channels|dms)/[^/]+$',
);

bool isConversationDeepLink(String path) {
  return _conversationLandingPattern.hasMatch(path);
}

final _notificationDeepLinkPattern = RegExp(
  r'^(/servers/[^/]+/(channels|dms)/[^/]+|/threads/[^/]+/replies|/agents/[^/]+|/profile/[^/]+)$',
);

bool isNotificationDeepLink(String path) {
  return _notificationDeepLinkPattern.hasMatch(path);
}

String? extractDeepLinkServerId(String path) {
  final segments = Uri.parse(path).pathSegments;
  if (segments.length >= 2 && segments[0] == 'servers') {
    return segments[1];
  }
  return null;
}
