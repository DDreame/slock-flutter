// =============================================================================
// #827 — Semantic Gaps B: Screenshot Canvas + Voice Waveform LiveRegion +
//        ToolButton Selected + "Unread"/"All" Hardcoded Strings
//
// Phase A: Tests proving accessibility semantics and l10n exist.
//
// Load-bearing proof:
//   1. AnnotationToolbar _ToolButton exposes selected state to SR
//   2. VoiceRecorderWidget waveform has liveRegion semantics
//   3. ScreenshotAnnotatePage canvas has semantic label
//   4. UnreadListPage "Unread"/"All" filter chip renders localized text
// =============================================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/home/presentation/page/unread_list_page.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/screenshot/application/screenshot_store.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/data/screenshot_state.dart';
import 'package:slock_app/features/screenshot/presentation/page/screenshot_annotate_page.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_toolbar.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_recorder_widget.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ===========================================================================
  // 1. ToolButton — selected state exposed to SR
  // ===========================================================================

  group('#827 — AnnotationToolbar ToolButton selected semantics', () {
    Widget buildToolbar({
      AnnotationTool selectedTool = AnnotationTool.freehand,
      Locale locale = const Locale('en'),
    }) {
      return MaterialApp(
        locale: locale,
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AnnotationToolbar(
            selectedTool: selectedTool,
            selectedColor: const Color(0xFFFF0000),
            canUndo: false,
            canRedo: false,
            onToolSelected: (_) {},
            onColorSelected: (_) {},
            onUndo: () {},
            onRedo: () {},
          ),
        ),
      );
    }

    testWidgets('selected tool button has selected semantics', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester
          .pumpWidget(buildToolbar(selectedTool: AnnotationTool.freehand));
      await tester.pumpAndSettle();

      // Find freehand button by tooltip — it should have selected: true.
      final drawButton = find.byTooltip('Draw');
      expect(drawButton, findsOneWidget);

      final semantics = tester.getSemantics(drawButton);
      expect(
        semantics.flagsCollection.isSelected,
        Tristate.isTrue,
        reason: 'Selected tool must expose isSelected to SR',
      );

      semanticsHandle.dispose();
    });

    testWidgets('non-selected tool button is NOT marked selected',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester
          .pumpWidget(buildToolbar(selectedTool: AnnotationTool.freehand));
      await tester.pumpAndSettle();

      // Arrow tool is NOT selected.
      final arrowButton = find.byTooltip('Arrow');
      expect(arrowButton, findsOneWidget);

      final semantics = tester.getSemantics(arrowButton);
      expect(
        semantics.flagsCollection.isSelected,
        Tristate.isFalse,
        reason: 'Non-selected tool must not have isSelected flag',
      );

      semanticsHandle.dispose();
    });
  });

  // ===========================================================================
  // 2. Voice recorder waveform — live region
  // ===========================================================================

  group('#827 — Voice recorder waveform live region', () {
    testWidgets('waveform has Semantics with liveRegion', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceMessageStoreProvider
                .overrideWith(() => _FakeVoiceMessageStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VoiceRecorderWidget(
                onSend: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final waveform = find.byKey(const ValueKey('voice-waveform'));
      expect(waveform, findsOneWidget);

      final semantics = tester.getSemantics(waveform);
      expect(semantics.flagsCollection.isLiveRegion, isTrue);

      semanticsHandle.dispose();
    });
  });

  // ===========================================================================
  // 3. Screenshot canvas — semantic label
  // ===========================================================================

  group('#827 — Screenshot canvas semantics', () {
    testWidgets('canvas area has semantic label from l10n', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenshotStoreProvider.overrideWith(() => _FakeScreenshotStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ScreenshotAnnotatePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final canvas = find.byKey(const ValueKey('screenshot-canvas'));
      expect(canvas, findsOneWidget);

      final semantics = tester.getSemantics(canvas);
      expect(semantics.label, l10n.screenshotCanvasSemantics);

      semanticsHandle.dispose();
    });
  });

  // ===========================================================================
  // 4. "Unread"/"All" filter — l10n
  // ===========================================================================

  group('#827 — Unread/All filter chip l10n', () {
    Widget buildUnreadPage({
      Locale locale = const Locale('zh'),
      InboxFilter filter = InboxFilter.unread,
    }) {
      return ProviderScope(
        overrides: [
          inboxStoreProvider.overrideWith(() => _FakeInboxStore(filter)),
          unreadSourceProjectionProvider.overrideWithValue(
            UnreadSourceProjectionState(isLoaded: true),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UnreadListPage(serverId: 'test-server'),
        ),
      );
    }

    testWidgets('"Unread" chip is localized in ZH', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

      await tester.pumpWidget(buildUnreadPage(filter: InboxFilter.unread));
      await tester.pumpAndSettle();

      // Must NOT show English "Unread" in ZH locale.
      expect(find.text('Unread'), findsNothing);
      // Must show the ZH localized label.
      expect(find.text(l10n.unreadFilterLabel), findsOneWidget);
    });

    testWidgets('"All" chip is localized in ZH', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

      await tester.pumpWidget(buildUnreadPage(filter: InboxFilter.all));
      await tester.pumpAndSettle();

      // Must NOT show English "All" in ZH locale.
      expect(find.text('All'), findsNothing);
      // Must show the ZH localized label.
      expect(find.text(l10n.allFilterLabel), findsOneWidget);
    });
  });
}

// =============================================================================
// Test helpers — fake stores for provider overrides
// =============================================================================

/// Provides a recording state with amplitudes for the waveform to render.
class _FakeVoiceMessageStore extends VoiceMessageStore {
  @override
  VoiceMessageState build() {
    seedAmplitudes([0.5, 0.3, 0.8, 0.2, 0.6]);
    return const VoiceMessageState(
      recordingState: VoiceRecorderState.recording,
      amplitudeCount: 5,
    );
  }
}

/// Provides a screenshot state with a fake image path so the annotate page
/// renders its full canvas layout (not the "no capture" fallback).
class _FakeScreenshotStore extends ScreenshotStore {
  @override
  ScreenshotState build() =>
      const ScreenshotState(imagePath: '/fake-screenshot.png');
}

/// Provides inbox state at success with the given filter so the filter chip
/// renders without triggering load().
class _FakeInboxStore extends InboxStore {
  _FakeInboxStore(this._filter);

  final InboxFilter _filter;

  @override
  InboxState build() => InboxState(
        status: InboxStatus.success,
        filter: _filter,
      );
}
