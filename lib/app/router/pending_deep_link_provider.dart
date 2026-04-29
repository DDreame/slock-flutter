import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

final _invitePattern = RegExp(r'^/invite/([^/]+)$');

bool isInviteDeepLink(String path) {
  return _invitePattern.hasMatch(Uri.parse(path).path);
}

String? extractInviteToken(String path) {
  final match = _invitePattern.firstMatch(Uri.parse(path).path);
  return match?.group(1);
}

final _conversationLandingPattern = RegExp(
  r'^/servers/[^/]+/(channels|dms)/[^/]+$',
);

bool isConversationDeepLink(String path) {
  return _conversationLandingPattern.hasMatch(Uri.parse(path).path);
}

final _notificationDeepLinkPattern = RegExp(
  r'^(/servers/[^/]+/(channels|dms)/[^/]+|/servers/[^/]+/threads/[^/]+/replies|/servers/[^/]+/agents/[^/]+|/servers/[^/]+/profile/[^/]+|/profile/[^/]+)$',
);

bool isNotificationDeepLink(String path) {
  return _notificationDeepLinkPattern.hasMatch(Uri.parse(path).path);
}

String? extractDeepLinkServerId(String path) {
  final segments = Uri.parse(path).pathSegments;
  if (segments.length >= 2 && segments[0] == 'servers') {
    return segments[1];
  }
  return null;
}
