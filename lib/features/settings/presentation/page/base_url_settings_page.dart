import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/features/settings/data/base_url_connection_tester.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/base_url/base_url_settings_store.dart';

class BaseUrlSettingsPage extends ConsumerStatefulWidget {
  const BaseUrlSettingsPage({super.key});

  @override
  ConsumerState<BaseUrlSettingsPage> createState() =>
      _BaseUrlSettingsPageState();
}

class _BaseUrlSettingsPageState extends ConsumerState<BaseUrlSettingsPage> {
  late TextEditingController _apiController;
  late TextEditingController _realtimeController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(baseUrlSettingsStoreProvider).settings;
    _apiController = TextEditingController(text: settings.apiBaseUrl);
    _realtimeController = TextEditingController(text: settings.realtimeUrl);
  }

  @override
  void dispose() {
    _apiController.dispose();
    _realtimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(baseUrlSettingsStoreProvider);
    final l10n = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.baseUrlSettingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          // --- API Base URL ---
          Text(
            l10n.baseUrlApiLabel,
            style: AppTypography.title.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('base-url-api-field'),
                  controller: _apiController,
                  decoration: InputDecoration(
                    hintText: l10n.baseUrlApiHint,
                    helperText: _apiController.text.isEmpty
                        ? l10n.baseUrlEmptyDefault
                        : null,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (value) {
                    ref
                        .read(
                          baseUrlSettingsStoreProvider.notifier,
                        )
                        .setApiBaseUrl(value);
                  },
                ),
                if (state.apiTestResult != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ConnectionResultChip(
                    key: const ValueKey(
                      'base-url-api-result',
                    ),
                    result: state.apiTestResult!,
                    colors: colors,
                    l10n: l10n,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          // --- Realtime URL ---
          Text(
            l10n.baseUrlRealtimeLabel,
            style: AppTypography.title.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey(
                    'base-url-realtime-field',
                  ),
                  controller: _realtimeController,
                  decoration: InputDecoration(
                    hintText: l10n.baseUrlRealtimeHint,
                    helperText: _realtimeController.text.isEmpty
                        ? l10n.baseUrlEmptyDefault
                        : null,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (value) {
                    ref
                        .read(
                          baseUrlSettingsStoreProvider.notifier,
                        )
                        .setRealtimeUrl(value);
                  },
                ),
                if (state.realtimeTestResult != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ConnectionResultChip(
                    key: const ValueKey(
                      'base-url-realtime-result',
                    ),
                    result: state.realtimeTestResult!,
                    colors: colors,
                    l10n: l10n,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // --- Action buttons ---
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey(
                    'base-url-test-connection',
                  ),
                  onPressed: state.isTesting ? null : _testConnection,
                  icon: state.isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(
                    state.isTesting
                        ? l10n.baseUrlTesting
                        : l10n.baseUrlTestConnection,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('base-url-save'),
                  onPressed: state.isTesting ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(l10n.baseUrlSave),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const ValueKey(
                    'base-url-restore-defaults',
                  ),
                  onPressed: state.isTesting ? null : _restoreDefaults,
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.baseUrlRestoreDefaults),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final store = ref.read(baseUrlSettingsStoreProvider.notifier);
    final errorKey = await store.save();
    if (!mounted) return;

    if (errorKey != null) {
      final message = switch (errorKey) {
        'baseUrlApiInvalid' => l10n.baseUrlApiInvalidError,
        'baseUrlRealtimeInvalid' => l10n.baseUrlRealtimeInvalidError,
        _ => errorKey,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.baseUrlSaved)),
    );
  }

  Future<void> _restoreDefaults() async {
    final l10n = context.l10n;
    final store = ref.read(baseUrlSettingsStoreProvider.notifier);
    await store.restoreDefaults();
    if (!mounted) return;

    _apiController.text = '';
    _realtimeController.text = '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.baseUrlRestored)),
    );
  }

  Future<void> _testConnection() async {
    await ref.read(baseUrlSettingsStoreProvider.notifier).testConnection();
  }
}

class _ConnectionResultChip extends StatelessWidget {
  const _ConnectionResultChip({
    super.key,
    required this.result,
    required this.colors,
    required this.l10n,
  });

  final ConnectionTestResult result;
  final AppColors colors;
  final dynamic l10n;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (result) {
      ConnectionTestResult.reachable => (
          l10n.baseUrlResultReachable as String,
          colors.success,
        ),
      ConnectionTestResult.reachableUnauthorized => (
          l10n.baseUrlResultUnauthorized as String,
          colors.warning,
        ),
      ConnectionTestResult.timeout => (
          l10n.baseUrlResultTimeout as String,
          colors.error,
        ),
      ConnectionTestResult.invalidUrl => (
          l10n.baseUrlResultInvalid as String,
          colors.error,
        ),
    };

    return Row(
      children: [
        Icon(
          result == ConnectionTestResult.reachable
              ? Icons.check_circle
              : result == ConnectionTestResult.reachableUnauthorized
                  ? Icons.warning_amber
                  : Icons.error_outline,
          size: 16,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: color),
        ),
      ],
    );
  }
}
