import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/onboarding_settings_repository.dart';
import 'package:slock_app/features/servers/data/onboarding_settings_repository_provider.dart';
import 'package:slock_app/features/servers/presentation/page/onboarding_settings_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  Widget buildPage({
    required _FakeOnboardingSettingsRepo repo,
    String serverId = 'srv-1',
  }) {
    return ProviderScope(
      overrides: [
        onboardingSettingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: OnboardingSettingsPage(serverId: serverId),
      ),
    );
  }

  testWidgets('shows loading state while fetching settings', (tester) async {
    final completer = Completer<OnboardingSettings>();
    final repo = _FakeOnboardingSettingsRepo(getCompleter: completer);

    await tester.pumpWidget(buildPage(repo: repo));

    expect(find.byKey(const ValueKey('onboarding-settings-loading')),
        findsOneWidget);

    completer.complete(const OnboardingSettings(
      setupModalReminderOptOut: false,
      onboardingReminderOptOut: false,
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('displays toggle with current value', (tester) async {
    final repo = _FakeOnboardingSettingsRepo(
      settings: const OnboardingSettings(
        setupModalReminderOptOut: true,
        onboardingReminderOptOut: false,
      ),
    );

    await tester.pumpWidget(buildPage(repo: repo));
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const ValueKey(
      'onboarding-setup-modal-toggle',
    ));
    expect(switchFinder, findsOneWidget);

    final switchWidget = tester.widget<SwitchListTile>(switchFinder);
    expect(switchWidget.value, isTrue);
  });

  testWidgets('toggling switch calls updateSettings', (tester) async {
    final repo = _FakeOnboardingSettingsRepo(
      settings: const OnboardingSettings(
        setupModalReminderOptOut: false,
        onboardingReminderOptOut: false,
      ),
    );

    await tester.pumpWidget(buildPage(repo: repo));
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const ValueKey(
      'onboarding-setup-modal-toggle',
    ));
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(repo.updateCalls.length, 1);
    expect(repo.updateCalls.first.$2, isTrue);
  });

  testWidgets('shows error state on load failure', (tester) async {
    final repo = _FakeOnboardingSettingsRepo(
      getFailure: const ServerFailure(
        message: 'Internal error',
        statusCode: 500,
      ),
    );

    await tester.pumpWidget(buildPage(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('onboarding-settings-error')),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry reloads settings after failure', (tester) async {
    final repo = _FakeOnboardingSettingsRepo(
      getFailure: const ServerFailure(
        message: 'Internal error',
        statusCode: 500,
      ),
    );

    await tester.pumpWidget(buildPage(repo: repo));
    await tester.pumpAndSettle();

    expect(repo.getCalls, 1);

    // Clear the failure for retry.
    repo.getFailure = null;
    repo.settings = const OnboardingSettings(
      setupModalReminderOptOut: false,
      onboardingReminderOptOut: false,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repo.getCalls, 2);
    expect(find.byKey(const ValueKey('onboarding-setup-modal-toggle')),
        findsOneWidget);
  });

  testWidgets('shows snackbar on update failure', (tester) async {
    final repo = _FakeOnboardingSettingsRepo(
      settings: const OnboardingSettings(
        setupModalReminderOptOut: false,
        onboardingReminderOptOut: false,
      ),
      updateFailure: const ServerFailure(
        message: 'Permission denied',
        statusCode: 403,
      ),
    );

    await tester.pumpWidget(buildPage(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey(
      'onboarding-setup-modal-toggle',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}

class _FakeOnboardingSettingsRepo implements OnboardingSettingsRepository {
  _FakeOnboardingSettingsRepo({
    this.settings,
    this.getFailure,
    this.updateFailure,
    this.getCompleter,
  });

  OnboardingSettings? settings;
  AppFailure? getFailure;
  AppFailure? updateFailure;
  Completer<OnboardingSettings>? getCompleter;
  int getCalls = 0;
  final List<(ServerScopeId, bool)> updateCalls = [];

  @override
  Future<OnboardingSettings> getSettings(ServerScopeId serverId) async {
    getCalls++;
    if (getCompleter != null) return getCompleter!.future;
    if (getFailure != null) throw getFailure!;
    return settings ??
        const OnboardingSettings(
          setupModalReminderOptOut: false,
          onboardingReminderOptOut: false,
        );
  }

  @override
  Future<OnboardingSettings> updateSettings(
    ServerScopeId serverId, {
    required bool setupModalReminderOptOut,
  }) async {
    updateCalls.add((serverId, setupModalReminderOptOut));
    if (updateFailure != null) throw updateFailure!;
    settings = (settings ??
            const OnboardingSettings(
              setupModalReminderOptOut: false,
              onboardingReminderOptOut: false,
            ))
        .copyWith(setupModalReminderOptOut: setupModalReminderOptOut);
    return settings!;
  }
}
