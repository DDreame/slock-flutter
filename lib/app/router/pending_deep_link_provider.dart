import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

final _conversationLandingPattern = RegExp(
  r'^/servers/[^/]+/(channels|dms)/[^/]+$',
);

bool isConversationDeepLink(String path) {
  return _conversationLandingPattern.hasMatch(path);
}
