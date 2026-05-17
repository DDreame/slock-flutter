import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';

// ---------------------------------------------------------------------------
// #536: Notification Deep Link — Phase A
//
// Verifies that resolveNotificationRoute() propagates messageId from the
// notification payload into the route URL as a query parameter.
//
// Currently, resolveNotificationRoute() reads serverId, channelId, threadId
// etc. but drops messageId — the field is never extracted from the payload.
// The downstream infrastructure (GoRouter routes, ConversationDetailPage
// highlightMessageId, scroll-to-message) already supports it, so this is
// the only gap.
//
// Invariants:
//   INV-DEEPLINK-1: channel payload with messageId → route includes
//                   ?messageId= query param
//   INV-DEEPLINK-2: DM payload with messageId → route includes ?messageId=
//   INV-DEEPLINK-3: thread payload with messageId → route includes
//                   messageId in query params alongside channelId
//   INV-DEEPLINK-4: payloads without messageId → route has no messageId
//                   query param (backward compat)
//
// Phase A: INV-DEEPLINK-1/2/3 skip:true — messageId not read in
// resolveNotificationRoute(). INV-DEEPLINK-4 is skip:false (current
// behavior — must not regress).
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-DEEPLINK-1: Channel notification with messageId includes it in
  // the route URL.
  //
  // Setup: Call resolveNotificationRoute with type=channel, serverId,
  // channelId, and messageId. The returned URL must contain
  // ?messageId=<value>.
  //
  // skip:true — resolveNotificationRoute does not read messageId.
  // -----------------------------------------------------------------------
  test(
    'channel payload with messageId includes query param (INV-DEEPLINK-1)',
    skip: true,
    () {
      final route = resolveNotificationRoute({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'messageId': 'msg-uuid-1',
      });
      expect(route, isNotNull);
      final uri = Uri.parse(route!);
      expect(uri.path, '/servers/s1/channels/c1');
      expect(
        uri.queryParameters['messageId'],
        'msg-uuid-1',
        reason: 'Channel route must include messageId query param '
            '(INV-DEEPLINK-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-DEEPLINK-2: DM notification with messageId includes it in the
  // route URL.
  //
  // Setup: Call resolveNotificationRoute with type=dm, serverId,
  // channelId, and messageId. The returned URL must contain
  // ?messageId=<value>.
  //
  // skip:true — resolveNotificationRoute does not read messageId.
  // -----------------------------------------------------------------------
  test(
    'dm payload with messageId includes query param (INV-DEEPLINK-2)',
    skip: true,
    () {
      final route = resolveNotificationRoute({
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'dm1',
        'messageId': 'msg-uuid-2',
      });
      expect(route, isNotNull);
      final uri = Uri.parse(route!);
      expect(uri.path, '/servers/s1/dms/dm1');
      expect(
        uri.queryParameters['messageId'],
        'msg-uuid-2',
        reason: 'DM route must include messageId query param '
            '(INV-DEEPLINK-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-DEEPLINK-3: Thread notification with messageId includes it in
  // the route URL alongside the existing channelId query param.
  //
  // Setup: Call resolveNotificationRoute with type=thread, serverId,
  // channelId, threadId, and messageId. The returned URL must contain
  // both ?channelId=<value>&messageId=<value>.
  //
  // skip:true — resolveNotificationRoute does not read messageId.
  // -----------------------------------------------------------------------
  test(
    'thread payload with messageId includes both channelId and messageId '
    'query params (INV-DEEPLINK-3)',
    skip: true,
    () {
      final route = resolveNotificationRoute({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'c1',
        'threadId': 't1',
        'messageId': 'msg-uuid-3',
      });
      expect(route, isNotNull);
      final uri = Uri.parse(route!);
      expect(uri.path, '/servers/s1/threads/t1/replies');
      expect(uri.queryParameters['channelId'], 'c1');
      expect(
        uri.queryParameters['messageId'],
        'msg-uuid-3',
        reason: 'Thread route must include messageId query param '
            '(INV-DEEPLINK-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-DEEPLINK-4: Payloads without messageId must NOT add an empty or
  // null messageId query parameter (backward compatibility).
  //
  // This invariant is already satisfied by the current code and must not
  // regress when the fix is applied.
  //
  // skip:false — this tests current behavior.
  // -----------------------------------------------------------------------
  test(
    'payloads without messageId have no messageId query param '
    '(INV-DEEPLINK-4)',
    () {
      // Channel without messageId.
      final channelRoute = resolveNotificationRoute({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
      });
      expect(channelRoute, isNotNull);
      expect(
        channelRoute!.contains('messageId'),
        isFalse,
        reason: 'Channel route without messageId must not contain '
            'messageId param (INV-DEEPLINK-4)',
      );

      // DM without messageId.
      final dmRoute = resolveNotificationRoute({
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'dm1',
      });
      expect(dmRoute, isNotNull);
      expect(
        dmRoute!.contains('messageId'),
        isFalse,
        reason: 'DM route without messageId must not contain '
            'messageId param (INV-DEEPLINK-4)',
      );

      // Thread without messageId.
      final threadRoute = resolveNotificationRoute({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'c1',
        'threadId': 't1',
      });
      expect(threadRoute, isNotNull);
      expect(
        threadRoute!.contains('messageId'),
        isFalse,
        reason: 'Thread route without messageId must not contain '
            'messageId param (INV-DEEPLINK-4)',
      );
    },
  );
}
