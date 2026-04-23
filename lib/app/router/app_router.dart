import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/app/shell/app_shell.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/auth/presentation/page/forgot_password_page.dart';
import 'package:slock_app/features/auth/presentation/page/login_page.dart';
import 'package:slock_app/features/auth/presentation/page/register_page.dart';
import 'package:slock_app/features/billing/presentation/page/billing_page.dart';
import 'package:slock_app/features/channels/presentation/page/channel_members_page.dart';
import 'package:slock_app/features/channels/presentation/page/channel_page.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/machines/presentation/page/machines_page.dart';
import 'package:slock_app/features/members/presentation/page/members_page.dart';
import 'package:slock_app/features/messages/presentation/page/messages_page.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/features/release_notes/presentation/page/release_notes_page.dart';
import 'package:slock_app/features/saved_messages/presentation/page/saved_messages_page.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/features/splash/presentation/page/splash_page.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/features/threads/presentation/page/thread_replies_page.dart';
import 'package:slock_app/features/threads/presentation/page/threads_page.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

const _authRoutes = {'/login', '/register', '/forgot-password'};

@visibleForTesting
String? authRedirect(SessionState session, String path) {
  final isSplash = path == '/splash';
  final isAuthRoute = _authRoutes.contains(path);

  if (session.status == AuthStatus.unknown) {
    return isSplash ? null : '/splash';
  }
  if (session.isUnauthenticated && !isAuthRoute && !isSplash) {
    return '/login';
  }
  if (session.isAuthenticated && (isAuthRoute || isSplash)) {
    return '/home';
  }
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _SessionRouterNotifier(ref);

  String? syncServerSelection(BuildContext context, GoRouterState state) {
    final serverId = state.pathParameters['serverId'];
    if (serverId != null) {
      ref.read(serverSelectionStoreProvider.notifier).selectServer(serverId);
    }
    return null;
  }

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = ref.read(sessionStoreProvider);
      final path = state.uri.path;
      final bootstrapComplete = ref.read(appReadyProvider);

      if (session.status == AuthStatus.unknown &&
          isNotificationDeepLink(path)) {
        ref.read(pendingDeepLinkProvider.notifier).state = state.uri.toString();
      }

      if (path == '/splash' && session.isAuthenticated && !bootstrapComplete) {
        return null;
      }

      final redirect = authRedirect(session, path);

      if (redirect == '/home') {
        final pending = ref.read(pendingDeepLinkProvider);
        if (pending != null) {
          ref.read(pendingDeepLinkProvider.notifier).state = null;
          if (isConversationDeepLink(pending)) {
            final pendingServerId = extractDeepLinkServerId(pending);
            final servers = ref.read(serverListStoreProvider).servers;
            if (pendingServerId != null &&
                servers.any((s) => s.id == pendingServerId)) {
              return pending;
            }
          } else if (isNotificationDeepLink(pending)) {
            return pending;
          }
        }
      }

      return redirect;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/agents',
            builder: (context, state) => const AgentsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        redirect: syncServerSelection,
        builder: (context, state) => ChannelPage(
          serverId: state.pathParameters['serverId']!,
          channelId: state.pathParameters['channelId']!,
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId/members',
        redirect: syncServerSelection,
        builder: (context, state) => ChannelMembersPage(
          serverId: state.pathParameters['serverId']!,
          channelId: state.pathParameters['channelId']!,
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        redirect: syncServerSelection,
        builder: (context, state) => MessagesPage(
          serverId: state.pathParameters['serverId']!,
          channelId: state.pathParameters['channelId']!,
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/threads',
        redirect: syncServerSelection,
        builder: (context, state) =>
            ThreadsPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/threads/:threadId/replies',
        redirect: syncServerSelection,
        builder: (context, state) {
          final target = tryParseThreadRouteTarget(state.uri);
          return ThreadRepliesPage(routeTarget: target);
        },
      ),
      GoRoute(
        path: '/servers/:serverId/tasks',
        redirect: syncServerSelection,
        builder: (context, state) =>
            TasksPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/agents',
        redirect: syncServerSelection,
        builder: (context, state) =>
            AgentsPage(serverId: state.pathParameters['serverId']),
      ),
      GoRoute(
        path: '/agents/:agentId',
        builder: (context, state) =>
            AgentsPage(agentId: state.pathParameters['agentId']),
      ),
      GoRoute(
        path: '/servers/:serverId/machines',
        redirect: syncServerSelection,
        builder: (context, state) =>
            MachinesPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/search',
        redirect: syncServerSelection,
        builder: (context, state) =>
            SearchPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/members',
        redirect: syncServerSelection,
        builder: (context, state) =>
            MembersPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/saved-messages',
        redirect: syncServerSelection,
        builder: (context, state) =>
            SavedMessagesPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) =>
            ProfilePage(userId: state.pathParameters['userId']),
      ),
      GoRoute(
        path: '/servers/:serverId/profile/:userId',
        redirect: syncServerSelection,
        builder: (context, state) => ProfilePage(
          serverId: state.pathParameters['serverId'],
          userId: state.pathParameters['userId'],
        ),
      ),
      GoRoute(
        path: '/billing',
        builder: (context, state) => const BillingPage(),
      ),
      GoRoute(
        path: '/release-notes',
        builder: (context, state) => const ReleaseNotesPage(),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );

  ref.listen<String?>(pendingDeepLinkProvider, (prev, next) {
    if (next == null) return;
    final session = ref.read(sessionStoreProvider);
    final bootstrapComplete = ref.read(appReadyProvider);
    if (!session.isAuthenticated || !bootstrapComplete) return;

    ref.read(pendingDeepLinkProvider.notifier).state = null;
    if (isConversationDeepLink(next)) {
      final serverId = extractDeepLinkServerId(next);
      final servers = ref.read(serverListStoreProvider).servers;
      if (serverId != null && servers.any((s) => s.id == serverId)) {
        router.go(next);
      }
    } else if (isNotificationDeepLink(next)) {
      router.go(next);
    }
  });

  return router;
});

class _SessionRouterNotifier extends ChangeNotifier {
  _SessionRouterNotifier(this._ref) {
    _ref.listen<SessionState>(sessionStoreProvider, (_, next) {
      if (!next.isAuthenticated) {
        _ref.read(appReadyProvider.notifier).state = false;
      }
      notifyListeners();
    });
    _ref.listen<bool>(appReadyProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
