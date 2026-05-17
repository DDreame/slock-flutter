import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/core/telemetry/crash_breadcrumb_observer.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/app/shell/app_shell.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/auth/presentation/page/forgot_password_page.dart';
import 'package:slock_app/features/auth/presentation/page/login_page.dart';
import 'package:slock_app/features/auth/presentation/page/register_page.dart';
import 'package:slock_app/features/auth/presentation/page/reset_password_page.dart';
import 'package:slock_app/features/auth/presentation/page/verify_email_page.dart';
import 'package:slock_app/features/biometric/presentation/page/biometric_lock_page.dart';
import 'package:slock_app/features/billing/presentation/page/billing_page.dart';
import 'package:slock_app/features/channels/presentation/page/channel_members_page.dart';
import 'package:slock_app/features/channels/presentation/page/channel_page.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/channel_files_page.dart';
import 'package:slock_app/features/conversation/presentation/page/pinned_messages_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/file_preview_page.dart';
import 'package:slock_app/features/dms/presentation/page/dms_tab_page.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/home/presentation/page/unread_list_page.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/features/machines/presentation/page/machines_page.dart';
import 'package:slock_app/features/members/presentation/page/members_page.dart';
import 'package:slock_app/features/messages/presentation/page/messages_page.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/features/release_notes/presentation/page/release_notes_page.dart';
import 'package:slock_app/features/saved_messages/presentation/page/saved_messages_page.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';
import 'package:slock_app/features/screenshot/presentation/page/screenshot_annotate_page.dart';
import 'package:slock_app/features/settings/presentation/page/base_url_settings_page.dart';
import 'package:slock_app/features/settings/presentation/page/diagnostics_page.dart';
import 'package:slock_app/features/settings/presentation/page/appearance_settings_page.dart';
import 'package:slock_app/features/settings/presentation/page/notification_settings_page.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/features/settings/presentation/page/translation_settings_page.dart';
import 'package:slock_app/features/splash/presentation/page/splash_page.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/features/threads/presentation/page/thread_replies_page.dart';
import 'package:slock_app/features/threads/presentation/page/threads_page.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/presentation/page/invite_landing_page.dart';
import 'package:slock_app/features/servers/presentation/page/workspace_settings_page.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/application/share_send_service.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';

const _authRoutes = {
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/verify-email',
};

/// Routes accessible regardless of authentication status.
const _publicRoutes = {
  '/settings/base-url',
};

/// Default transition duration for push/pop page animations.
const _transitionDuration = Duration(milliseconds: 300);

/// Wraps [child] in a [CustomTransitionPage] with an iOS-style slide-in
/// transition (right-to-left on push, left-to-right on pop).
///
/// Used by push-target routes to provide animated navigation instead of
/// the instant page swap produced by plain `builder:`.
CustomTransitionPage<void> _slideTransitionPage({
  required LocalKey key,
  required Widget child,
  String? name,
}) {
  return CustomTransitionPage<void>(
    key: key,
    name: name,
    child: child,
    transitionDuration: _transitionDuration,
    reverseTransitionDuration: _transitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        )),
        child: child,
      );
    },
  );
}

@visibleForTesting
String? authRedirect(SessionState session, String path) {
  final isSplash = path == '/splash';
  final isAuthRoute = _authRoutes.contains(path);
  final isPublicRoute = _publicRoutes.contains(path);
  final isTokenRecoveryRoute =
      path == '/reset-password' || path == '/verify-email';
  final needsEmailVerification =
      session.isAuthenticated && session.emailVerified == false;

  // Public routes bypass all auth redirects.
  if (isPublicRoute) return null;

  if (session.status == AuthStatus.unknown) {
    return isSplash || isTokenRecoveryRoute ? null : '/splash';
  }
  if (session.isUnauthenticated && !isAuthRoute && !isSplash) {
    return '/login';
  }
  if (needsEmailVerification) {
    return path == '/verify-email' ? null : '/verify-email';
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

  // Enable URL updates for push() / pushReplacement() so the address bar
  // and routeInformationProvider reflect the pushed route.  Without this,
  // GoRouter v14 defaults to keeping the URL at the shell's location,
  // which breaks deep-link back-stack verification and browser history.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = ref.read(sessionStoreProvider);
      final path = state.uri.path;
      final bootstrapComplete = ref.read(appReadyProvider);
      final resetToken = state.uri.queryParameters['reset'];
      final verifyToken = state.uri.queryParameters['verify'];

      if (resetToken != null && path != '/reset-password') {
        return Uri(
          path: '/reset-password',
          queryParameters: {'reset': resetToken},
        ).toString();
      }
      if (verifyToken != null && path != '/verify-email') {
        return Uri(
          path: '/verify-email',
          queryParameters: {'verify': verifyToken},
        ).toString();
      }

      if (session.status == AuthStatus.unknown &&
          isNotificationDeepLink(path)) {
        ref.read(pendingDeepLinkProvider.notifier).state = state.uri.toString();
      }

      if (!session.isAuthenticated && isInviteDeepLink(path)) {
        ref.read(pendingDeepLinkProvider.notifier).state = state.uri.toString();
      }

      if (path == '/splash' && session.isAuthenticated && !bootstrapComplete) {
        return null;
      }

      if (path == '/splash' && session.isUnauthenticated && bootstrapComplete) {
        return '/login';
      }

      // Biometric lock: redirect to lock page when authenticated but locked.
      final biometric = ref.read(biometricStoreProvider);
      if (session.isAuthenticated &&
          biometric.isLocked &&
          path != '/biometric-lock') {
        return '/biometric-lock';
      }
      // If unlocked but on the lock page, redirect to home.
      if (path == '/biometric-lock' && !biometric.isLocked) {
        return '/home';
      }

      final redirect = authRedirect(session, path);

      if (redirect == '/home') {
        final pending = ref.read(pendingDeepLinkProvider);
        if (pending != null) {
          ref.read(pendingDeepLinkProvider.notifier).state = null;
          if (isInviteDeepLink(pending)) {
            return pending;
          } else if (isConversationDeepLink(pending)) {
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
      GoRoute(
        path: '/biometric-lock',
        builder: (context, state) => const BiometricLockPage(),
      ),
      GoRoute(
        path: '/share-target',
        builder: (context, state) {
          return _ShareTargetRoute(ref: ref);
        },
      ),
      GoRoute(
        path: '/screenshot-annotate',
        builder: (context, state) => const ScreenshotAnnotatePage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['reset']),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            VerifyEmailPage(initialToken: state.uri.queryParameters['verify']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/channels',
                builder: (context, state) => const ChannelsTabPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dms',
                builder: (context, state) => const DmsTabPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agents',
                builder: (context, state) => const AgentsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbox',
                builder: (context, state) => const InboxPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.uri.path,
          child: const SettingsPage(),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        redirect: syncServerSelection,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.uri.path,
          child: ChannelPage(
            serverId: state.pathParameters['serverId']!,
            channelId: state.pathParameters['channelId']!,
            highlightMessageId: state.uri.queryParameters['messageId'],
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId/members',
        redirect: syncServerSelection,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.uri.path,
          child: ChannelMembersPage(
            serverId: state.pathParameters['serverId']!,
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId/pinned',
        redirect: syncServerSelection,
        pageBuilder: (context, state) {
          final target = state.extra as ConversationDetailTarget?;
          return _slideTransitionPage(
            key: state.pageKey,
            name: state.name ?? state.uri.path,
            child: ProviderScope(
              overrides: [
                if (target != null)
                  currentConversationDetailTargetProvider
                      .overrideWithValue(target),
              ],
              child: PinnedMessagesPage(
                onMessageTap: (id) => context.pop(id),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId/files',
        redirect: syncServerSelection,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.uri.path,
          child: ChannelFilesPage(
            serverId: state.pathParameters['serverId']!,
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/file-preview',
        builder: (context, state) {
          final attachment = state.extra as MessageAttachment;
          return FilePreviewPage(attachment: attachment);
        },
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        redirect: syncServerSelection,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.uri.path,
          child: MessagesPage(
            serverId: state.pathParameters['serverId']!,
            channelId: state.pathParameters['channelId']!,
            highlightMessageId: state.uri.queryParameters['messageId'],
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/threads',
        redirect: syncServerSelection,
        builder: (context, state) =>
            ThreadsPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/unread',
        redirect: syncServerSelection,
        builder: (context, state) =>
            UnreadListPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/threads/:threadId/replies',
        redirect: syncServerSelection,
        pageBuilder: (context, state) {
          final target = tryParseThreadRouteTarget(state.uri);
          return _slideTransitionPage(
            key: state.pageKey,
            name: state.name ?? state.uri.path,
            child: ThreadRepliesPage(routeTarget: target),
          );
        },
      ),
      GoRoute(
        path: '/servers/:serverId/tasks',
        redirect: syncServerSelection,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.uri.path,
          child: TasksPage(serverId: state.pathParameters['serverId']!),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/agents',
        redirect: syncServerSelection,
        builder: (context, state) =>
            AgentsPage(serverId: state.pathParameters['serverId']),
      ),
      GoRoute(
        path: '/servers/:serverId/agents/:agentId',
        redirect: syncServerSelection,
        builder: (context, state) => AgentsPage(
          serverId: state.pathParameters['serverId'],
          agentId: state.pathParameters['agentId'],
        ),
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
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.uri.path,
          child: SearchPage(serverId: state.pathParameters['serverId']!),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/settings',
        redirect: syncServerSelection,
        builder: (context, state) => WorkspaceSettingsPage(
          serverId: state.pathParameters['serverId']!,
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/members',
        redirect: syncServerSelection,
        builder: (context, state) =>
            MembersPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/saved',
        redirect: syncServerSelection,
        builder: (context, state) =>
            SavedMessagesPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          name: state.name ?? state.uri.path,
          child: const ProfilePage(),
        ),
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
        path: '/settings/appearance',
        builder: (context, state) => const AppearanceSettingsPage(),
      ),
      GoRoute(
        path: '/settings/translation',
        builder: (context, state) => const TranslationSettingsPage(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: '/settings/diagnostics',
        builder: (context, state) => const DiagnosticsPage(),
      ),
      GoRoute(
        path: '/settings/base-url',
        builder: (context, state) => const BaseUrlSettingsPage(),
      ),
      GoRoute(
        path: '/release-notes',
        builder: (context, state) => const ReleaseNotesPage(),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) => InviteLandingPage(
          token: state.pathParameters['token']!,
        ),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
    observers: [
      CrashBreadcrumbObserver(reporter: ref.read(crashReporterProvider)),
    ],
  );

  ref.listen<String?>(pendingDeepLinkProvider, (prev, next) {
    if (next == null) return;
    final session = ref.read(sessionStoreProvider);
    final bootstrapComplete = ref.read(appReadyProvider);
    if (!session.isAuthenticated || !bootstrapComplete) return;

    ref.read(pendingDeepLinkProvider.notifier).state = null;
    if (isInviteDeepLink(next)) {
      router.go(next);
    } else if (isConversationDeepLink(next)) {
      final serverId = extractDeepLinkServerId(next);
      final servers = ref.read(serverListStoreProvider).servers;
      if (serverId != null && servers.any((s) => s.id == serverId)) {
        // Push onto existing stack so back returns to the previous
        // in-app screen instead of wiping the navigation stack.
        // Scheduled via addPostFrameCallback to ensure the push
        // executes outside the Riverpod notification phase.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.push(next);
        });
      }
    } else if (isNotificationDeepLink(next)) {
      // Push onto existing stack so back returns to the previous
      // in-app screen instead of wiping the navigation stack.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.push(next);
      });
    }
  });

  // Navigate to share-target picker when new shared content arrives.
  // fireImmediately handles cold-start intents that were set before
  // the listener was registered.
  ref.listen<SharedContent?>(
    shareIntentStoreProvider,
    fireImmediately: true,
    (prev, next) {
      if (next == null || next.isEmpty) return;
      final session = ref.read(sessionStoreProvider);
      final bootstrapComplete = ref.read(appReadyProvider);
      if (!session.isAuthenticated || !bootstrapComplete) return;
      if (router.routeInformationProvider.value.uri.path == '/share-target') {
        return;
      }
      router.go('/share-target');
    },
  );

  // Re-check for pending share content when bootstrap completes,
  // so cold-start intents that arrived before auth/bootstrap are
  // not silently dropped.
  ref.listen<bool>(appReadyProvider, (prev, next) {
    if (next != true) return;
    final content = ref.read(shareIntentStoreProvider);
    if (content == null || content.isEmpty) return;
    final session = ref.read(sessionStoreProvider);
    if (!session.isAuthenticated) return;
    router.go('/share-target');
  });

  // Re-check for pending share content when the user logs in,
  // so intents that arrived while unauthenticated are routed
  // once the session becomes authenticated.
  ref.listen<SessionState>(sessionStoreProvider, (prev, next) {
    if (!next.isAuthenticated) return;
    if (prev?.isAuthenticated == true) return; // not a login transition
    final bootstrapComplete = ref.read(appReadyProvider);
    if (!bootstrapComplete) return;
    final content = ref.read(shareIntentStoreProvider);
    if (content == null || content.isEmpty) return;
    if (router.routeInformationProvider.value.uri.path == '/share-target') {
      return;
    }
    router.go('/share-target');
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
    _ref.listen<BiometricState>(biometricStoreProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

/// Wrapper that wires [ShareTargetPickerPage] callbacks to
/// [GoRouter] navigation and the share-send pipeline.
class _ShareTargetRoute extends StatelessWidget {
  const _ShareTargetRoute({required this.ref});

  final Ref ref;

  @override
  Widget build(BuildContext context) {
    return ShareTargetPickerPage(
      onTargetSelected: (target) async {
        final content = ref.read(shareIntentStoreProvider);
        if (content == null) {
          if (context.mounted) context.go('/home');
          return;
        }
        try {
          await ref
              .read(shareSendServiceProvider)
              .send(target: target, content: content);
          // Only consume on success — content is preserved on failure
          // so the user can retry.
          ref.read(shareIntentStoreProvider.notifier).consume();
          if (context.mounted) context.go('/home');
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to send. Please try again.'),
              ),
            );
          }
        }
      },
      onCancel: () {
        ref.read(shareIntentStoreProvider.notifier).consume();
        context.go('/home');
      },
    );
  }
}
