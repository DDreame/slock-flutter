import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/shell/app_shell.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/auth/presentation/page/login_page.dart';
import 'package:slock_app/features/channels/presentation/page/channel_page.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/messages/presentation/page/messages_page.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/features/release_notes/presentation/page/release_notes_page.dart';
import 'package:slock_app/features/saved_messages/presentation/page/saved_messages_page.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
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
        builder: (context, state) => ChannelPage(
          serverId: state.pathParameters['serverId']!,
          channelId: state.pathParameters['channelId']!,
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (context, state) => MessagesPage(
          serverId: state.pathParameters['serverId']!,
          channelId: state.pathParameters['channelId']!,
        ),
      ),
      GoRoute(
        path: '/agents/:agentId',
        builder: (context, state) => AgentsPage(
          agentId: state.pathParameters['agentId'],
        ),
      ),
      GoRoute(
        path: '/saved-messages',
        builder: (context, state) => const SavedMessagesPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) => ProfilePage(
          userId: state.pathParameters['userId'],
        ),
      ),
      GoRoute(
        path: '/release-notes',
        builder: (context, state) => const ReleaseNotesPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
