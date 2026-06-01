import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/bootstrap/app_bootstrap.dart';
import 'package:slock_app/app/bootstrap/fatal_bootstrap_screen.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/root_scaffold_messenger.dart';
import 'package:slock_app/core/notifications/background_sync_lifecycle_binding.dart';
import 'package:slock_app/core/notifications/foreground_service_lifecycle_binding.dart';
import 'package:slock_app/core/realtime/realtime.dart';
import 'package:slock_app/core/storage/flutter_secure_storage_impl.dart';
import 'package:slock_app/core/telemetry/crash_marker_service.dart';
import 'package:slock_app/core/telemetry/crash_recovery_wrapper.dart';
import 'package:slock_app/core/telemetry/zone_error_handler.dart';
import 'package:slock_app/features/push_token/application/push_token_lifecycle_binding.dart';
import 'package:slock_app/features/settings/data/base_url_settings.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/notification/notification_lifecycle_binding.dart';
import 'package:slock_app/stores/notification/notification_foreground_suppression_binding.dart';
import 'package:slock_app/stores/notification/notification_permission_onboarding_binding.dart';
import 'package:slock_app/core/notifications/background_worker_auth_binding.dart';
import 'package:slock_app/core/notifications/realtime_notification_bridge.dart';
import 'package:slock_app/features/home/application/home_refresh_lifecycle_binding.dart';
import 'package:slock_app/features/presence/data/presence_realtime_binding.dart';
import 'package:slock_app/stores/notification/notification_visible_target_binding.dart';
import 'package:slock_app/core/core.dart' show connectivityServiceProvider;
import 'package:slock_app/core/deep_link/deep_link_lifecycle_binding.dart';
import 'package:slock_app/core/network/connectivity_service.dart'
    show initConnectivityService;
import 'package:slock_app/features/servers/application/unread_summary_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/biometric/biometric_lock_lifecycle_binding.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read SharedPreferences early so saved base URL overrides are available
  // before bootstrap validates compile-time endpoints.
  final prefs = await SharedPreferences.getInstance();
  final savedBaseUrls = SharedPrefsBaseUrlRepository(prefs: prefs).load();

  // Start connectivity check before bootstrap so both run concurrently.
  // Connectivity init is a read-only platform channel call — safe to
  // overlap with reporter.init() inside appBootstrap().
  final connectivityFuture = initConnectivityService();

  final AppBootstrapResult bootstrap;
  try {
    bootstrap = await appBootstrap(
      savedBaseUrlSettings: savedBaseUrls,
    );
  } catch (error) {
    // Prevent connectivityFuture from becoming an unhandled async error
    // on the fatal-bootstrap path where nothing will ever await it.
    connectivityFuture.ignore();
    runApp(FatalBootstrapScreen(error: error));
    return;
  }

  final crashMarker = CrashMarkerService(
    storage: FlutterSecureStorageImpl(),
  );

  // Await connectivity (likely already resolved during bootstrap).
  final connectivityService = await connectivityFuture;

  installErrorHandlers(
    bootstrap.reporter,
    diagnostics: bootstrap.diagnostics,
    crashMarker: crashMarker,
  );

  runZonedGuarded(
    () async {
      final container = ProviderContainer(
        overrides: [
          ...bootstrap.overrides,
          crashMarkerServiceProvider.overrideWithValue(crashMarker),
          sharedPreferencesProvider.overrideWithValue(prefs),
          connectivityServiceProvider.overrideWithValue(connectivityService),
        ],
      );

      // Restore theme preference synchronously before first build
      // so the saved theme is the very first frame painted.
      final themeRepo = container.read(themePreferenceRepositoryProvider);
      container.read(themeModeStoreProvider.notifier).restoreFrom(themeRepo);

      // Restore biometric preferences before first frame so the lock screen
      // appears before authenticated content when enabled.
      await container.read(biometricStoreProvider.notifier).initialize();

      // Check biometric hardware availability (async, non-blocking).
      unawaited(
        container.read(biometricStoreProvider.notifier).checkAvailability(),
      );

      // Initialize share intent listener (async, non-blocking).
      unawaited(
        container.read(shareIntentStoreProvider.notifier).initialize(),
      );

      runApp(UncontrolledProviderScope(
        container: container,
        child: const SlockApp(),
      ));
    },
    (error, stack) {
      handleZoneError(
        error,
        stack,
        reporter: bootstrap.reporter,
        diagnostics: bootstrap.diagnostics,
        crashMarker: crashMarker,
      );
    },
  );
}

class SlockApp extends ConsumerWidget {
  const SlockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeModeStoreProvider);
    final router = ref.watch(appRouterProvider);
    return _LifecycleBindingsActivator(
      child: MaterialApp.router(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeState.themeMode,
        routerConfig: router,
        builder: (context, child) =>
            CrashRecoveryWrapper(child: child ?? const SizedBox.shrink()),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Activates lifecycle binding providers without contributing to the
/// widget tree output. Separated from [SlockApp] so that any internal
/// state emission from these 15 service providers does NOT force
/// [MaterialApp.router] to rebuild — only theme/router changes do.
class _LifecycleBindingsActivator extends ConsumerWidget {
  const _LifecycleBindingsActivator({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(realtimeLifecycleBindingProvider);
    ref.watch(foregroundServiceLifecycleBindingProvider);
    ref.watch(backgroundSyncLifecycleBindingProvider);
    ref.watch(pushTokenLifecycleBindingProvider);
    ref.watch(notificationLifecycleBindingProvider);
    ref.watch(notificationVisibleTargetBindingProvider);
    ref.watch(notificationForegroundSuppressionBindingProvider);
    ref.watch(realtimeNotificationBridgeProvider);
    ref.watch(homeRefreshLifecycleBindingProvider);
    ref.watch(notificationPermissionOnboardingBindingProvider);
    ref.watch(backgroundWorkerAuthBindingProvider);
    ref.watch(biometricLockLifecycleBindingProvider);
    ref.watch(presenceRealtimeBindingProvider);
    ref.watch(domainRuntimeEventRouterProvider);
    ref.watch(deepLinkLifecycleBindingProvider);
    ref.watch(unreadSummaryLifecycleBindingProvider);
    return child;
  }
}
