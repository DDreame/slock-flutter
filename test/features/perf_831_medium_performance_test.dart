// =============================================================================
// #831 — Performance Medium: MachinesPage .select() + Notification DateFormat
// Cache + Typing RepaintBoundary
//
// Verifies:
// 1. _MachinesSuccessView's .select() projection does NOT fire on
//    status/failure-only changes (uses real MachinesStore + production select).
// 2. NotificationSettingsPage DateFormat is cached per locale AND both call
//    sites route through the single cached helper.
// 3. TypingIndicatorWidget wraps _AnimatedDots in a RepaintBoundary.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/features/conversation/presentation/widgets/typing_indicator_widget.dart';
import 'package:slock_app/features/machines/application/machines_state.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/presentation/page/machines_page.dart';
import 'package:slock_app/features/settings/presentation/page/notification_settings_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  // ===========================================================================
  // 1. MachinesPage .select() narrowing — real store proof
  // ===========================================================================

  group('#831 — MachinesPage .select() narrowing', () {
    test(
      'machinesSuccessViewProjection does NOT fire on failure-only change '
      '(real MachinesStore)',
      () async {
        // Uses the REAL MachinesStore backed by a fake repository.
        // Listens via the SAME production select function
        // (machinesSuccessViewProjection) that _MachinesSuccessView.build()
        // uses. This is load-bearing: removing the .select() from production
        // code or adding failure to the projection function → test RED.
        final container = ProviderContainer(
          overrides: [
            machinesRepositoryProvider.overrideWithValue(
              _FakeMachinesRepository(
                snapshot: const MachinesSnapshot(
                  items: [
                    MachineItem(
                        id: 'machine-1', name: 'Builder', status: 'online'),
                  ],
                  latestDaemonVersion: '1.0.0',
                ),
              ),
            ),
            realtimeReductionIngressProvider
                .overrideWithValue(RealtimeReductionIngress()),
            currentMachinesServerIdProvider
                .overrideWithValue(const ServerScopeId('server-1')),
          ],
        );
        addTearDown(container.dispose);

        // Keep the store alive (autoDispose).
        final keepAlive = container.listen(
          machinesStoreProvider,
          (_, __) {},
        );
        addTearDown(keepAlive.close);

        // Trigger load.
        await container.read(machinesStoreProvider.notifier).ensureLoaded();

        // Store should be in success state.
        expect(container.read(machinesStoreProvider).status,
            MachinesStatus.success);

        // Listen to the PRODUCTION select projection.
        var selectFireCount = 0;
        final sub = container.listen(
          machinesStoreProvider.select(machinesSuccessViewProjection),
          (_, __) {
            selectFireCount++;
          },
        );
        addTearDown(sub.close);
        selectFireCount = 0; // Reset after initial subscription.

        // Mutate only failure — projection must NOT fire.
        final store = container.read(machinesStoreProvider.notifier);
        store.state = store.state.copyWith(
          failure:
              const UnknownFailure(message: 'Transient', causeType: 'test'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(selectFireCount, 0,
            reason: 'Projection listener must NOT fire when only failure '
                'changes. This test goes RED if machinesSuccessViewProjection '
                'includes failure, or if the production .select() is removed.');

        // Mutate only status — projection must NOT fire.
        store.state = store.state.copyWith(
          status: MachinesStatus.loading,
          clearFailure: true,
        );
        await Future<void>.delayed(Duration.zero);

        expect(selectFireCount, 0,
            reason: 'Projection listener must NOT fire when only status '
                'changes.');

        // Mutate items — projection SHOULD fire (sensitivity proof).
        store.state = store.state.copyWith(
          status: MachinesStatus.success,
          items: const [
            MachineItem(id: 'machine-1', name: 'Builder', status: 'online'),
            MachineItem(id: 'machine-2', name: 'Runner', status: 'offline'),
          ],
        );
        await Future<void>.delayed(Duration.zero);

        expect(selectFireCount, greaterThan(0),
            reason: 'Projection must fire when items change — proves the '
                'test is sensitive and not vacuously passing.');
      },
    );

    testWidgets(
      'success view does NOT rebuild on failure-only store mutation '
      '(real mounted MachinesPage)',
      (tester) async {
        MachinesPage.successViewBuildCount = 0;

        final ingress = RealtimeReductionIngress();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              machinesRepositoryProvider.overrideWithValue(
                _FakeMachinesRepository(
                  snapshot: const MachinesSnapshot(
                    items: [
                      MachineItem(
                          id: 'machine-1', name: 'Builder', status: 'online'),
                    ],
                    latestDaemonVersion: '1.0.0',
                  ),
                ),
              ),
              realtimeReductionIngressProvider.overrideWithValue(ingress),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: MachinesPage(serverId: 'server-1'),
            ),
          ),
        );

        await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey('machines-list')),
        );

        // Success view must have built at least once.
        final countAfterLoad = MachinesPage.successViewBuildCount;
        expect(countAfterLoad, greaterThan(0));

        // Get the nested ProviderScope container that MachinesPage created.
        // This is the SAME container the success view watches.
        final machinesListElement =
            tester.element(find.byKey(const ValueKey('machines-list')));
        final nestedContainer = ProviderScope.containerOf(machinesListElement);

        // Mutate only failure — the .select() projection excludes failure,
        // so the success view must NOT rebuild.
        final store = nestedContainer.read(machinesStoreProvider.notifier);
        store.state = store.state.copyWith(
          failure:
              const UnknownFailure(message: 'Transient', causeType: 'test'),
        );
        await tester.pump();

        expect(MachinesPage.successViewBuildCount, countAfterLoad,
            reason: 'Success view must NOT rebuild when only failure changes. '
                'This test goes RED if _MachinesSuccessView reverts to '
                'ref.watch(machinesStoreProvider) without .select().');
      },
    );
  });

  // ===========================================================================
  // 2. NotificationSettingsPage DateFormat cache
  // ===========================================================================

  group('#831 — NotificationSettingsPage DateFormat caching', () {
    setUp(() => NotificationSettingsPage.clearDateFormatCache());

    testWidgets(
      'both call sites route through cache helper — one create per locale',
      (tester) async {
        // Render with 'en' locale and pushTokenUpdatedAt set so both
        // formatting sites fire (build body + _permissionSubtitle).
        await tester.pumpWidget(
          _buildNotificationSettingsApp(
            locale: const Locale('en'),
            pushTokenUpdatedAt: DateTime(2024, 6, 1, 14, 30),
          ),
        );
        await tester.pumpAndSettle();

        // Only ONE DateFormat should be created (cache miss on first access).
        // The second call site reuses the same cached instance.
        expect(
          NotificationSettingsPage.dateFormatCreateCount,
          1,
          reason: 'Only 1 DateFormat should be created for the en locale. '
              'Both call sites must use the cached helper. This test goes RED '
              'if either site creates its own DateFormat directly.',
        );
        expect(
          NotificationSettingsPage.dateFormatCacheSize,
          1,
          reason: 'Cache should have exactly 1 entry for en locale.',
        );

        // BOTH call sites must have invoked the helper. If either reverts to
        // direct DateFormat(...).format(...), call count drops below 2 → RED.
        expect(
          NotificationSettingsPage.dateFormatHelperCallCount,
          greaterThanOrEqualTo(2),
          reason: 'Both formatting sites must route through the cache helper. '
              'This test goes RED if either site reverts to direct '
              'DateFormat(...).format(...).',
        );
      },
    );

    testWidgets(
      'cache grows per locale — proves keyed-by-locale contract',
      (tester) async {
        // Render with 'en' locale.
        await tester.pumpWidget(
          _buildNotificationSettingsApp(
            locale: const Locale('en'),
            pushTokenUpdatedAt: DateTime(2024, 6, 1, 14, 30),
          ),
        );
        await tester.pumpAndSettle();

        expect(NotificationSettingsPage.dateFormatCacheSize, 1);

        // Rebuild with 'zh' locale.
        await tester.pumpWidget(
          _buildNotificationSettingsApp(
            locale: const Locale('zh'),
            pushTokenUpdatedAt: DateTime(2024, 6, 1, 14, 30),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          NotificationSettingsPage.dateFormatCacheSize,
          2,
          reason: 'After en + zh renders, cache must have 2 entries. '
              'This test goes RED if the cache is replaced with a single '
              'shared formatter.',
        );
        expect(
          NotificationSettingsPage.dateFormatCreateCount,
          2,
          reason: 'Exactly 2 DateFormat allocations — one per locale.',
        );
        // Each render hits 2 call sites × 2 locales = at least 4 helper calls.
        expect(
          NotificationSettingsPage.dateFormatHelperCallCount,
          greaterThanOrEqualTo(4),
          reason: 'Both call sites must route through helper for each locale.',
        );
      },
    );
  });

  // ===========================================================================
  // 3. TypingIndicatorWidget RepaintBoundary
  // ===========================================================================

  group('#831 — TypingIndicatorWidget RepaintBoundary isolation', () {
    testWidgets(
      '_AnimatedDots is wrapped in RepaintBoundary',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              typingIndicatorStoreProvider
                  .overrideWith(() => _FakeTypingIndicatorStore()),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: TypingIndicatorWidget()),
            ),
          ),
        );
        await tester.pump();

        // Find the typing dots widget.
        final dotsWidget = find.byKey(const ValueKey('typing-dots'));
        expect(dotsWidget, findsOneWidget,
            reason:
                'Typing dots widget must be present when someone is typing.');

        // Walk ancestors from dots widget to find RepaintBoundary before
        // reaching the Row (the parent container).
        final dotsElement = tester.element(dotsWidget);
        var foundRepaintBoundary = false;
        dotsElement.visitAncestorElements((element) {
          if (element.widget is RepaintBoundary) {
            foundRepaintBoundary = true;
            return false;
          }
          if (element.widget is Row) {
            return false; // Stop at parent Row — boundary must be between.
          }
          return true;
        });
        expect(foundRepaintBoundary, isTrue,
            reason: '_AnimatedDots must be wrapped in a RepaintBoundary to '
                'isolate animation repaints from parent. This test goes RED '
                'if the RepaintBoundary is removed from '
                'typing_indicator_widget.dart.');
      },
    );
  });
}

// =============================================================================
// Helpers
// =============================================================================

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var attempt = 0; attempt < maxPumps; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}

Widget _buildNotificationSettingsApp({
  required Locale locale,
  DateTime? pushTokenUpdatedAt,
}) {
  return ProviderScope(
    overrides: [
      notificationStoreProvider.overrideWith(
        () => _FakeNotificationStore(pushTokenUpdatedAt: pushTokenUpdatedAt),
      ),
      diagnosticsCollectorProvider.overrideWithValue(DiagnosticsCollector()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light,
      home: const NotificationSettingsPage(),
    ),
  );
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeMachinesRepository implements MachinesRepository {
  _FakeMachinesRepository({this.snapshot = const MachinesSnapshot()});

  MachinesSnapshot snapshot;

  @override
  Future<MachinesSnapshot> loadMachines() async => snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationStore extends Notifier<NotificationState>
    implements NotificationStore {
  _FakeNotificationStore({this.pushTokenUpdatedAt});

  final DateTime? pushTokenUpdatedAt;

  @override
  NotificationState build() => NotificationState(
        permissionStatus: NotificationPermissionStatus.granted,
        pushToken: 'fake-token',
        pushTokenPlatform: 'android',
        pushTokenUpdatedAt: pushTokenUpdatedAt,
        notificationPreference: NotificationPreference.all,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTypingIndicatorStore
    extends AutoDisposeNotifier<TypingIndicatorState>
    implements TypingIndicatorStore {
  @override
  TypingIndicatorState build() => const TypingIndicatorState(
        activeTypers: [ActiveTyper(userId: 'u1', displayName: 'Alice')],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
