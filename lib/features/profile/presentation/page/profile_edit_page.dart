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
    final l10n = context.l10n;
    if (state.status == ProfileEditStatus.success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.profileEditSnackbarSaved)));
      if (context.canPop()) context.pop();
    } else if (state.failure != null) {
      // Surface partial success when avatar was committed but profile
      // PATCH failed — user should know retry won't re-upload (#799).
      final message = state.avatarCommitted
          ? l10n.profileEditSnackbarAvatarSavedProfileFailed
          : (state.failure?.userMessage(l10n) ?? l10n.errorUnknown);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileEditStoreProvider);
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profileEditTitle),
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
                : Text(context.l10n.profileEditSave),
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
                      context.l10n.profileEditNewAvatarSelected,
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
                    label: Text(context.l10n.profileEditChangeAvatar),
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
                    context.l10n.profileEditSectionDetails,
                    style: AppTypography.title.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const ValueKey('profile-edit-display-name'),
                    controller: _displayNameController,
                    enabled: !state.isSaving,
                    decoration: InputDecoration(
                      labelText: context.l10n.profileEditDisplayNameLabel,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: ref
                        .read(profileEditStoreProvider.notifier)
                        .setDisplayName,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.profileEditDisplayNameRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const ValueKey('profile-edit-bio'),
                    controller: _bioController,
                    enabled: !state.isSaving,
                    decoration: InputDecoration(
                      labelText: context.l10n.profileEditBioLabel,
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
