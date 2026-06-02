import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/application/onboarding_settings_use_case.dart';
import 'package:slock_app/features/servers/data/onboarding_settings_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

class OnboardingSettingsPage extends ConsumerStatefulWidget {
  const OnboardingSettingsPage({required this.serverId, super.key});

  final String serverId;

  @override
  ConsumerState<OnboardingSettingsPage> createState() =>
      _OnboardingSettingsPageState();
}

class _OnboardingSettingsPageState
    extends ConsumerState<OnboardingSettingsPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  OnboardingSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final getSettings = ref.read(getOnboardingSettingsUseCaseProvider);
      final settings = await getSettings(ServerScopeId(widget.serverId));
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = failure.userMessage(context.l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = context.l10n.onboardingSettingsLoadError;
      });
    }
  }

  Future<void> _toggleSetupModalReminder(bool value) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final updateSettings = ref.read(updateOnboardingSettingsUseCaseProvider);
      final updated = await updateSettings(
        ServerScopeId(widget.serverId),
        setupModalReminderOptOut: value,
      );
      if (!mounted) return;
      setState(() {
        _settings = updated;
        _isSaving = false;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.userMessage(context.l10n))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.onboardingSettingsSaveError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.onboardingSettingsTitle)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const AppLoadingIndicator(
        key: ValueKey('onboarding-settings-loading'),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                key: const ValueKey('onboarding-settings-error'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadSettings,
                child: Text(l10n.onboardingSettingsRetry),
              ),
            ],
          ),
        ),
      );
    }

    final settings = _settings;
    if (settings == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.onboardingSettingsDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('onboarding-setup-modal-toggle'),
          title: Text(l10n.onboardingSettingsSetupModalLabel),
          subtitle: Text(l10n.onboardingSettingsSetupModalDescription),
          value: settings.setupModalReminderOptOut,
          onChanged: _isSaving ? null : _toggleSetupModalReminder,
        ),
      ],
    );
  }
}
