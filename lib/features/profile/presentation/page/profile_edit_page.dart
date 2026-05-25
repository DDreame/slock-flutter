import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/core/errors/app_failure_user_message.dart';
import 'package:slock_app/features/profile/application/profile_edit_store.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:slock_app/l10n/l10n.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(profileEditStoreProvider);
    _displayNameController = TextEditingController(text: initial.displayName);
    _bioController = TextEditingController(text: initial.bio);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(profileEditStoreProvider.notifier).save();
    if (!mounted) return;
    final state = ref.read(profileEditStoreProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (state.status == ProfileEditStatus.success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated.')));
      if (context.canPop()) context.pop();
    } else if (state.failure != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(state.failure?.userMessage(context.l10n) ??
                context.l10n.errorUnknown),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileEditStoreProvider);
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            key: const ValueKey('profile-edit-save'),
            onPressed: state.isSaving ? null : _save,
            child: state.isSaving
                ? const SizedBox(
                    key: ValueKey('profile-edit-saving-indicator'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ProfileAvatar(
                    displayName: state.displayName,
                    avatarUrl: state.avatarUrl,
                    radius: 42,
                  ),
                  if (state.selectedAvatarPath != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'New avatar selected',
                      key: const ValueKey('profile-edit-avatar-selected'),
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    key: const ValueKey('profile-edit-avatar-button'),
                    onPressed: state.isSaving
                        ? null
                        : () => ref
                            .read(profileEditStoreProvider.notifier)
                            .pickAvatar(),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Change avatar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile details',
                    style: AppTypography.title.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const ValueKey('profile-edit-display-name'),
                    controller: _displayNameController,
                    enabled: !state.isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: ref
                        .read(profileEditStoreProvider.notifier)
                        .setDisplayName,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Display name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const ValueKey('profile-edit-bio'),
                    controller: _bioController,
                    enabled: !state.isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Bio / status',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    onChanged:
                        ref.read(profileEditStoreProvider.notifier).setBio,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
