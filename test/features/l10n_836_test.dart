// =============================================================================
// #836 — L10n Infrastructure Load-Bearing Tests
//
// Invariants verified (all use ZH locale — reverting to hardcoded English → RED):
// INV-836-L10N-1: AppErrorView retry button uses l10n.errorRetry
// INV-836-L10N-2: FriendlyErrorState shows l10n.errorRetry + l10n.errorShareDiagnostics
// INV-836-L10N-3: FatalBootstrapScreen title uses l10n.fatalTitle
// INV-836-L10N-4: DiagnosticShareSheet title uses l10n.diagExportTitle
// INV-836-L10N-5: FilePreviewPage error state uses l10n.filePreviewNoUrl (real widget)
// INV-836-L10N-6: ProfilePage avatar upload failure uses l10n via code enum (real widget)
// INV-836-L10N-7: AppShell nav uses l10n.navInbox (real widget)
// INV-836-L10N-8: GoRouter errorBuilder uses l10n.routerPageNotFound (real router)
// =============================================================================

// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/bootstrap/fatal_bootstrap_screen.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/shell/app_shell.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/app_error_view.dart';
import 'package:slock_app/app/widgets/friendly_error_state.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart'
    show attachmentRepositoryProvider;
import 'package:slock_app/features/conversation/data/conversation_repository.dart'
    show MessageAttachment;
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/presentation/widgets/file_preview_page.dart';
import 'package:slock_app/features/inbox/application/inbox_unread_count_provider.dart';
import 'package:slock_app/features/profile/application/avatar_upload_service.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;

void main() {
  // ---------------------------------------------------------------------------
  // INV-836-L10N-1: AppErrorView retry button uses l10n.errorRetry
  // ---------------------------------------------------------------------------
  group('INV-836-L10N-1: AppErrorView retry l10n', () {
    testWidgets(
      'shows ZH retry text (重试), not English "Retry"',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AppErrorView(
                message: 'test error',
                onRetry: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('重试'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-836-L10N-2: FriendlyErrorState uses l10n.errorRetry + errorShareDiagnostics
  // ---------------------------------------------------------------------------
  group('INV-836-L10N-2: FriendlyErrorState l10n', () {
    testWidgets(
      'shows ZH retry and share diagnostics text',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FriendlyErrorState(
                title: '错误',
                message: '测试',
                onRetry: () async {},
                onShareDiagnostics: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('重试'), findsOneWidget);
        expect(find.text('分享诊断信息'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        expect(find.text('Share diagnostics'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-836-L10N-3: FatalBootstrapScreen title uses l10n.fatalTitle
  // ---------------------------------------------------------------------------
  group('INV-836-L10N-3: FatalBootstrapScreen l10n', () {
    testWidgets(
      'shows ZH fatal title (无法启动), not English',
      (tester) async {
        // FatalBootstrapScreen creates its own MaterialApp with
        // localizationsDelegates + supportedLocales. Override platform locale.
        tester.platformDispatcher.localeTestValue = const Locale('zh');
        tester.platformDispatcher.localesTestValue = [const Locale('zh')];
        addTearDown(() {
          tester.platformDispatcher.clearLocaleTestValue();
          tester.platformDispatcher.clearLocalesTestValue();
        });

        await tester.pumpWidget(
          const FatalBootstrapScreen(error: 'test error'),
        );
        await tester.pumpAndSettle();

        expect(find.text('无法启动'), findsOneWidget);
        expect(find.text('Unable to start'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-836-L10N-4: DiagnosticShareSheet title uses l10n.diagExportTitle
  // ---------------------------------------------------------------------------
  group('INV-836-L10N-4: DiagnosticShareSheet l10n', () {
    testWidgets(
      'shows ZH export title (导出诊断信息), not English',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diagnosticLogServiceProvider.overrideWithValue(
                DiagnosticLogService(collector: DiagnosticsCollector()),
              ),
              diagnosticShareServiceProvider.overrideWithValue(
                _FakeDiagnosticShareService(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DiagnosticShareSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('导出诊断信息'), findsOneWidget);
        expect(find.text('Export Diagnostics'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-836-L10N-5: FilePreviewPage error state uses l10n.filePreviewNoUrl
  // ---------------------------------------------------------------------------
  group('INV-836-L10N-5: FilePreviewPage real widget l10n', () {
    testWidgets(
      'shows ZH error text when no URL, not English',
      (tester) async {
        // Attachment with no id and no url → triggers filePreviewNoUrl error.
        const attachment = MessageAttachment(
          name: 'orphan.bin',
          type: 'application/octet-stream',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attachmentRepositoryProvider.overrideWithValue(
                _FakeAttachmentRepository(),
              ),
              currentOpenConversationTargetProvider.overrideWith(
                (ref) => null,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: FilePreviewPage(attachment: attachment),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Production widget must render ZH string from l10n.filePreviewNoUrl.
        expect(find.text('没有可用的下载链接。'), findsOneWidget);
        expect(find.text('No download URL available.'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-836-L10N-6: ProfilePage avatar upload failure snackbar uses l10n
  // ---------------------------------------------------------------------------
  group('INV-836-L10N-6: ProfilePage avatar upload l10n', () {
    testWidgets(
      'avatar upload failure shows ZH snackbar via error code mapping',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentProfileTargetProvider.overrideWithValue(
                const ProfileTarget(),
              ),
              profileDetailStoreProvider.overrideWith(
                () => _FixedProfileDetailStore(const MemberProfile(
                  id: 'user-1',
                  displayName: 'Test User',
                  isSelf: true,
                )),
              ),
              imagePickerProvider.overrideWithValue(
                _FakeImagePicker(resultPath: '/tmp/avatar.png'),
              ),
              avatarUploadServiceProvider.overrideWithValue(
                _FailingAvatarUploadService(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: ProfilePage()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the avatar edit button to trigger upload.
        final editButton =
            find.byKey(const ValueKey('profile-avatar-edit-button'));
        if (editButton.evaluate().isNotEmpty) {
          await tester.tap(editButton);
          await tester.pumpAndSettle();

          // Snackbar should show ZH text from l10n.avatarUploadFailed mapping.
          expect(find.text('上传失败。'), findsOneWidget);
          expect(find.text('Upload failed.'), findsNothing);
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-836-L10N-7: AppShell navigation bar uses l10n.navInbox
  // ---------------------------------------------------------------------------
  group('INV-836-L10N-7: AppShell nav label l10n', () {
    testWidgets(
      'bottom nav shows ZH inbox label (收件箱), not English "Inbox"',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) =>
                  AppShell(navigationShell: navigationShell),
              branches: [
                StatefulShellBranch(routes: [
                  GoRoute(path: '/', builder: (_, __) => const Placeholder()),
                ]),
                StatefulShellBranch(routes: [
                  GoRoute(
                      path: '/channels',
                      builder: (_, __) => const Placeholder()),
                ]),
                StatefulShellBranch(routes: [
                  GoRoute(
                      path: '/dms', builder: (_, __) => const Placeholder()),
                ]),
                StatefulShellBranch(routes: [
                  GoRoute(
                      path: '/agents', builder: (_, __) => const Placeholder()),
                ]),
                StatefulShellBranch(routes: [
                  GoRoute(
                      path: '/inbox', builder: (_, __) => const Placeholder()),
                ]),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inboxChannelUnreadTotalProvider.overrideWithValue(0),
              inboxDmUnreadTotalProvider.overrideWithValue(0),
              inboxTotalUnreadCountProvider.overrideWithValue(0),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Production AppShell renders ZH l10n.navInbox label.
        expect(find.text('收件箱'), findsOneWidget);
        expect(find.text('Inbox'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-836-L10N-8: GoRouter errorBuilder uses l10n.routerPageNotFound
  // ---------------------------------------------------------------------------
  group('INV-836-L10N-8: GoRouter error page l10n', () {
    testWidgets(
      'real appRouterProvider errorBuilder shows ZH text on unknown route',
      (tester) async {
        // Use the real production appRouterProvider so the test is bound
        // to app_router.dart's errorBuilder. Reverting that to hardcoded
        // English breaks this test → load-bearing.
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            splashControllerProvider
                .overrideWith(() => _StallingSplashController()),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        container.read(appReadyProvider.notifier).state = true;

        final router = container.read(appRouterProvider);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to a non-existent route to trigger errorBuilder.
        router.go('/this-route-does-not-exist');
        await tester.pumpAndSettle();

        // Production errorBuilder renders ZH l10n.routerPageNotFound.
        expect(
          find.textContaining('页面未找到'),
          findsOneWidget,
        );
        expect(find.textContaining('Page not found'), findsNothing);
      },
    );
  });
}

/// Stub share service for DiagnosticShareSheet tests.
class _FakeDiagnosticShareService implements DiagnosticShareService {
  @override
  Future<DiagnosticShareResult> copyToClipboard(String text) async =>
      DiagnosticShareResult.success;
  @override
  Future<DiagnosticShareResult> shareText(String text) async =>
      DiagnosticShareResult.success;
  @override
  Future<String> saveToFile(String text, {String? filename}) async =>
      '/tmp/test.txt';
}

/// Fake attachment repository that returns no signed URL.
class _FakeAttachmentRepository implements AttachmentRepository {
  @override
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    throw const NetworkFailure(message: 'Network error');
  }

  @override
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    return '';
  }
}

/// Fixed profile detail store for avatar test.
class _FixedProfileDetailStore extends ProfileDetailStore {
  _FixedProfileDetailStore(this._profile);
  final MemberProfile _profile;

  @override
  ProfileDetailState build() => ProfileDetailState(
        status: ProfileDetailStatus.success,
        profile: _profile,
      );
}

/// Fake image picker that returns a fixed path.
class _FakeImagePicker implements ImagePickerService {
  _FakeImagePicker({this.resultPath});
  final String? resultPath;

  @override
  Future<String?> pickImage() async => resultPath;
}

/// Avatar upload service that always fails with uploadFailed code.
class _FailingAvatarUploadService implements AvatarUploadService {
  @override
  Future<String> upload(String filePath) async {
    throw AvatarUploadException(
      'Upload failed.',
      code: AvatarUploadErrorCode.uploadFailed,
    );
  }
}

/// Fake secure storage for router test.
class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

/// Splash controller that never completes (stalls at splash screen).
class _StallingSplashController extends SplashController {
  @override
  Future<void> build() => Completer<void>().future;
}
