import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/bootstrap/app_bootstrap.dart';
import 'package:slock_app/app/bootstrap/fatal_bootstrap_screen.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/notifications/background_sync_lifecycle_binding.dart';
import 'package:slock_app/core/notifications/foreground_service_lifecycle_binding.dart';
import 'package:slock_app/core/realtime/realtime.dart';
import 'package:slock_app/core/storage/flutter_secure_storage_impl.dart';
import 'package:slock_app/core/telemetry/crash_marker_service.dart';
import 'package:slock_app/core/telemetry/crash_recovery_wrapper.dart';
import 'package:slock_app/features/home/application/home_realtime_dm_materialization_binding.dart';
import 'package:slock_app/features/home/application/home_realtime_unread_binding.dart';
import 'package:slock_app/features/push_token/application/push_token_lifecycle_binding.dart';
import 'package:slock_app/features/settings/data/base_url_settings.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_session_binding.dart';
import 'package:slock_app/stores/notification/notification_lifecycle_binding.dart';
import 'package:slock_app/stores/notification/notification_foreground_suppression_binding.dart';
import 'package:slock_app/stores/notification/notification_permission_onboarding_binding.dart';
import 'package:slock_app/stores/notification/notification_visible_target_binding.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read SharedPreferences early so saved base URL overrides are available
  // before bootstrap validates compile-time endpoints.
  final prefs = await SharedPreferences.getInstance();
  final savedBaseUrls = SharedPrefsBaseUrlRepository(prefs: prefs).load();

  final AppBootstrapResult bootstrap;
  try {
    bootstrap = await appBootstrap(
      savedBaseUrlSettings: savedBaseUrls,
    );
  } catch (error) {
    runApp(FatalBootstrapScreen(error: error));
    return;
  }

  final crashMarker = CrashMarkerService(
    storage: FlutterSecureStorageImpl(),
  );

  installErrorHandlers(
    bootstrap.reporter,
    diagnostics: bootstrap.diagnostics,
    crashMarker: crashMarker,
  );

  runZonedGuarded(
    () {
      final container = ProviderContainer(
        overrides: [
          ...bootstrap.overrides,
          crashMarkerServiceProvider.overrideWithValue(crashMarker),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      // Restore theme preference synchronously before first build
      // so the saved theme is the very first frame painted.
      final themeRepo = container.read(themePreferenceRepositoryProvider);
      container.read(themeModeStoreProvider.notifier).restoreFrom(themeRepo);

      runApp(UncontrolledProviderScope(
        container: container,
        child: const SlockApp(),
      ));
    },
    (error, stack) {
      bootstrap.reporter.captureException(error, stackTrace: stack);
      bootstrap.diagnostics.error('crash', error.toString());
      crashMarker.markCrash();
    },
  );
}

class SlockApp extends ConsumerWidget {
  const SlockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(realtimeLifecycleBindingProvider);
    ref.watch(foregroundServiceLifecycleBindingProvider);
    ref.watch(backgroundSyncLifecycleBindingProvider);
    ref.watch(homeRealtimeUnreadBindingProvider);
    ref.watch(homeRealtimeDmMaterializationBindingProvider);
    ref.watch(pushTokenLifecycleBindingProvider);
    ref.watch(notificationLifecycleBindingProvider);
    ref.watch(notificationVisibleTargetBindingProvider);
    ref.watch(notificationForegroundSuppressionBindingProvider);
    ref.watch(notificationPermissionOnboardingBindingProvider);
    ref.watch(channelUnreadSessionBindingProvider);
    final themeState = ref.watch(themeModeStoreProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
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
    );
  }
}
