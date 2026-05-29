import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Full-page form for creating a new channel.
///
/// Fields: name (required), description (optional), visibility (public/private).
class CreateChannelPage extends ConsumerStatefulWidget {
  const CreateChannelPage({super.key});

  @override
  ConsumerState<CreateChannelPage> createState() => _CreateChannelPageState();
}

class _CreateChannelPageState extends ConsumerState<CreateChannelPage> {
  // Hoisted BorderRadius for input fields (Scan #49).
  static final _kInputBorderRadius = BorderRadius.circular(12);

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final ServerScopeId? _serverId;
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _serverId = ref.read(activeServerScopeIdProvider);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(channelManagementStoreProvider);
    final colors = Theme.of(context).extension<AppColors>();
    final isSubmitting = state.isRunning(ChannelManagementAction.create);
    final name = _nameController.text.trim();
    final canSubmit = name.isNotEmpty && !isSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.channelsCreateTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel(label: context.l10n.channelsCreateSectionName),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('create-channel-name'),
              controller: _nameController,
              enabled: !isSubmitting,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '# ',
                prefixStyle: AppTypography.body.copyWith(
                  color: colors?.textTertiary ??
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                hintText: context.l10n.channelsCreateNameHint,
                border: OutlineInputBorder(
                  borderRadius: _kInputBorderRadius,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            _SectionLabel(label: context.l10n.channelsCreateSectionDescription),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('create-channel-description'),
              controller: _descriptionController,
              enabled: !isSubmitting,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: context.l10n.channelsCreateDescriptionHint,
                border: OutlineInputBorder(
                  borderRadius: _kInputBorderRadius,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel(label: context.l10n.channelsCreateSectionVisibility),
            const SizedBox(height: 8),
            _VisibilitySelector(
              isPrivate: _isPrivate,
              enabled: !isSubmitting,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),
            const Spacer(),
            FilledButton(
              key: const ValueKey('create-channel-submit'),
              onPressed: canSubmit ? _handleSubmit : null,
              child: Text(isSubmitting
                  ? context.l10n.channelsCreateSubmitting
                  : context.l10n.channelsCreateSubmit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final store = ref.read(channelManagementStoreProvider.notifier);
    final serverId = _serverId;
    if (serverId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.channelsCreateNoServer)),
        );
      return;
    }

    try {
      final channelId = await store.createChannel(
        name,
        serverId: serverId,
        description: description.isEmpty ? null : description,
        isPrivate: _isPrivate,
      );
      if (!mounted) return;
      // Pop back, returning the channel ID for navigation.
      Navigator.of(context).pop(channelId);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.userMessage(context.l10n)),
          ),
        );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    return Text(
      label,
      style: AppTypography.caption.copyWith(
        color: colors?.textSecondary ??
            Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector({
    required this.isPrivate,
    required this.enabled,
    required this.onChanged,
  });

  final bool isPrivate;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    final accent = colors?.primary ?? Theme.of(context).colorScheme.primary;
    final surface = colors?.surface ?? Theme.of(context).colorScheme.surface;
    final border =
        colors?.border ?? Theme.of(context).colorScheme.outlineVariant;
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _VisibilityOption(
            key: const ValueKey('create-channel-visibility-public'),
            label: l10n.channelsCreateVisibilityPublic,
            sublabel: l10n.channelsCreateVisibilityPublicSub,
            isSelected: !isPrivate,
            accent: accent,
            surface: surface,
            border: border,
            onTap: enabled ? () => onChanged(false) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _VisibilityOption(
            key: const ValueKey('create-channel-visibility-private'),
            label: l10n.channelsCreateVisibilityPrivate,
            sublabel: l10n.channelsCreateVisibilityPrivateSub,
            isSelected: isPrivate,
            accent: accent,
            surface: surface,
            border: border,
            onTap: enabled ? () => onChanged(true) : null,
          ),
        ),
      ],
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  // Hoisted BorderRadius for option card (Scan #49).
  static final _kCardBorderRadius = BorderRadius.circular(12);

  const _VisibilityOption({
    super.key,
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.accent,
    required this.surface,
    required this.border,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool isSelected;
  final Color accent;
  final Color surface;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? accent.withAlpha(20) : surface,
            borderRadius: _kCardBorderRadius,
            border: Border.all(
              color: isSelected ? accent : border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: isSelected ? accent : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: AppTypography.caption.copyWith(
                  color:
                      Theme.of(context).extension<AppColors>()?.textTertiary ??
                          Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
