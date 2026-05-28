// =============================================================================
// #565 Phase A — Connection State Banner
//
// Feature: Show a "Reconnecting..." banner when WebSocket is disconnected.
// Auto-dismiss on reconnect. Uses existing RealtimeConnectionStatus.
//
// Phase B: Implement ConnectionStatusBanner widget + wire into pages.
//
// Phase B — all tests active.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/connection_status_banner.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/core/realtime/realtime_service.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  group('ConnectionStatusBanner', () {
    Widget buildApp({
      required RealtimeConnectionState connectionState,
    }) {
      return ProviderScope(
        overrides: [
          realtimeServiceProvider.overrideWith(() {
            return _FakeRealtimeService(connectionState);
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: Column(
              children: [
                ConnectionStatusBanner(),
                Expanded(child: Placeholder()),
              ],
            ),
          ),
        ),
      );
    }

    // T1: Banner hidden when socket connected
    testWidgets(
      'hidden when socket status is connected',
      (tester) async {
        await tester.pumpWidget(buildApp(
          connectionState: const RealtimeConnectionState(
            status: RealtimeConnectionStatus.connected,
          ),
        ));
        await tester.pumpAndSettle();

        // Banner should not be visible.
        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsNothing,
        );
      },
    );

    // T2: Banner shows "Reconnecting..." when disconnected (after grace period)
    testWidgets(
      'shows reconnecting text when disconnected',
      (tester) async {
        await tester.pumpWidget(buildApp(
          connectionState: const RealtimeConnectionState(
            status: RealtimeConnectionStatus.disconnected,
          ),
        ));
        // #859: Advance past 2s grace period before banner appears.
        await tester.pump(bannerGracePeriod);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsOneWidget,
        );
        // Should display reconnecting/disconnected message.
        expect(find.textContaining('Reconnecting'), findsOneWidget);
      },
    );

    // T3: Banner shows "Reconnecting..." when reconnecting (after grace period)
    testWidgets(
      'shows reconnecting text when status is reconnecting',
      (tester) async {
        await tester.pumpWidget(buildApp(
          connectionState: const RealtimeConnectionState(
            status: RealtimeConnectionStatus.reconnecting,
          ),
        ));
        // #859: Advance past 2s grace period before banner appears.
        await tester.pump(bannerGracePeriod);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsOneWidget,
        );
        expect(find.textContaining('Reconnecting'), findsOneWidget);
      },
    );

    // T4: Banner auto-dismisses on reconnect (disconnected → connected)
    testWidgets(
      'auto-dismisses when status transitions to connected',
      (tester) async {
        // Start with disconnected.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              realtimeServiceProvider.overrideWith(() {
                return _FakeRealtimeService(const RealtimeConnectionState(
                  status: RealtimeConnectionStatus.disconnected,
                ));
              }),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const Scaffold(
                body: Column(
                  children: [
                    ConnectionStatusBanner(),
                    Expanded(child: Placeholder()),
                  ],
                ),
              ),
            ),
          ),
        );
        // #859: Advance past 2s grace period.
        await tester.pump(bannerGracePeriod);
        await tester.pump();

        // Banner visible while disconnected.
        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsOneWidget,
        );

        // Simulate reconnection by transitioning notifier state directly.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ConnectionStatusBanner)),
        );
        container.read(realtimeServiceProvider.notifier).state =
            const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        );
        await tester.pumpAndSettle();

        // Banner should be gone after reconnection.
        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsNothing,
        );
      },
    );

    // T5: Banner uses correct styling (surfaceAlt bg, caption text)
    testWidgets(
      'uses subtle informational background and caption text style',
      (tester) async {
        await tester.pumpWidget(buildApp(
          connectionState: const RealtimeConnectionState(
            status: RealtimeConnectionStatus.disconnected,
          ),
        ));
        // #859: Advance past 2s grace period.
        await tester.pump(bannerGracePeriod);
        await tester.pump();

        final banner = tester.widget<Container>(
          find.byKey(const ValueKey('connection-status-banner')),
        );
        final decoration = banner.decoration as BoxDecoration?;
        // Subtle informational banner — not warning/alarm colored.
        expect(decoration?.color, AppColors.light.surfaceAlt);

        // Text should use caption style.
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('connection-status-banner')),
            matching: find.byType(Text),
          ),
        );
        expect(text.style?.fontSize, AppTypography.caption.fontSize);
      },
    );
  });
}

// -----------------------------------------------------------------------------
// Fake RealtimeService that emits a fixed connection state.
// -----------------------------------------------------------------------------
class _FakeRealtimeService extends RealtimeService {
  _FakeRealtimeService(this._state);

  final RealtimeConnectionState _state;

  @override
  RealtimeConnectionState build() => _state;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}
}
