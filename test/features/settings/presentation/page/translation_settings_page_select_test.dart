// =============================================================================
// #609 — ref.listen .select() narrows — translation_settings_page
//
// Invariant: INV-TRANSLATION-LISTEN-SELECT-1
//   The ref.listen in TranslationSettingsPage (L41) only inspects `next.status`
//   to decide whether to re-trigger ensureLoaded(). Mutations to other state
//   fields (settings, failure) must NOT fire the listener.
//
// Strategy:
// T1: settings change must NOT fire status-select (skip:true).
// T2: failure change must NOT fire status-select (skip:true).
// T3: status change DOES fire status-select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.listen.
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.listen(translationSettingsStoreProvider, ...) at L41 with
// ref.listen(translationSettingsStoreProvider.select((s) => s.status), ...).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableTranslationSettingsStore extends TranslationSettingsStore {
  @override
  TranslationSettingsState build() => const TranslationSettingsState(
        status: TranslationSettingsStatus.success,
      );

  void setSettingsDirect(TranslationSettings settings) {
    state = state.copyWith(settings: settings);
  }

  void setFailureDirect(AppFailure? f) {
    state = TranslationSettingsState(
      status: state.status,
      settings: state.settings,
      failure: f,
    );
  }

  void setStatusDirect(TranslationSettingsStatus s) {
    state = state.copyWith(status: s);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: settings change must NOT fire status-select.
  // -------------------------------------------------------------------------
  test(
    'INV-TRANSLATION-LISTEN-SELECT-1: settings change does NOT notify '
    'status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          translationSettingsStoreProvider
              .overrideWith(() => _ControllableTranslationSettingsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(translationSettingsStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        translationSettingsStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(translationSettingsStoreProvider.notifier)
          as _ControllableTranslationSettingsStore;
      store.setSettingsDirect(const TranslationSettings(
        preferredLanguage: 'zh',
      ));

      expect(
        selectNotifyCount,
        0,
        reason: 'settings change must not notify status select '
            '(INV-TRANSLATION-LISTEN-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: false, // Phase B: .select() fix applied
  );

  // -------------------------------------------------------------------------
  // T2: failure change must NOT fire status-select.
  // -------------------------------------------------------------------------
  test(
    'INV-TRANSLATION-LISTEN-SELECT-1: failure change does NOT notify '
    'status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          translationSettingsStoreProvider
              .overrideWith(() => _ControllableTranslationSettingsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(translationSettingsStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        translationSettingsStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(translationSettingsStoreProvider.notifier)
          as _ControllableTranslationSettingsStore;
      store.setFailureDirect(
        const UnknownFailure(message: 'network error'),
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'failure change must not notify status select '
            '(INV-TRANSLATION-LISTEN-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: false, // Phase B: .select() fix applied
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire status-select.
  // -------------------------------------------------------------------------
  test(
    'INV-TRANSLATION-LISTEN-SELECT-1: status change DOES notify '
    'status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          translationSettingsStoreProvider
              .overrideWith(() => _ControllableTranslationSettingsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(translationSettingsStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        translationSettingsStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(translationSettingsStoreProvider.notifier)
          as _ControllableTranslationSettingsStore;
      store.setStatusDirect(TranslationSettingsStatus.initial);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify status select',
      );

      keepAlive.close();
    },
  );
}
