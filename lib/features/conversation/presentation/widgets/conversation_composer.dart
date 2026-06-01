import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/core/errors/app_failure_user_message.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/utils/sender_label_l10n.dart';
import 'package:slock_app/features/conversation/presentation/widgets/composer_keyboard_handler.dart';
import 'package:slock_app/features/conversation/presentation/widgets/formatting_toolbar.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_recorder_widget.dart';
import 'package:slock_app/l10n/l10n.dart';

AppLocalizations _conversationL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

class ConversationComposer extends ConsumerWidget {
  const ConversationComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.isRecording,
    required this.isFormattingToolbarVisible,
    required this.isEmojiPickerVisible,
    required this.onToggleFormattingToolbar,
    required this.onToggleEmojiPicker,
    required this.onChanged,
    required this.onSend,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
    required this.onCancelUpload,
    required this.onClearReply,
    required this.onMicTap,
    required this.onSendRecording,
    required this.onCancelRecording,
    this.enterToSend = false,
    this.asTask = false,
    this.onToggleAsTask,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ConversationDetailState state;
  final bool isRecording;
  final bool isFormattingToolbarVisible;
  final bool isEmojiPickerVisible;
  final VoidCallback onToggleFormattingToolbar;
  final VoidCallback onToggleEmojiPicker;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;
  final ValueChanged<PendingAttachment> onPickAttachment;
  final ValueChanged<int> onRemoveAttachment;
  final ValueChanged<int> onCancelUpload;
  final VoidCallback onClearReply;
  final VoidCallback onMicTap;
  final VoidCallback onSendRecording;
  final VoidCallback onCancelRecording;
  final bool enterToSend;

  /// Whether the next message will be created as a task.
  final bool asTask;

  /// Callback to toggle the [asTask] state.
  final VoidCallback? onToggleAsTask;

  /// Hoisted border radius to avoid per-build allocation (#851).
  @visibleForTesting
  static final BorderRadius inputBorderRadius =
      BorderRadius.circular(AppSpacing.radiusFull);

  /// Hoisted content padding to avoid per-build allocation (#851).
  @visibleForTesting
  static const EdgeInsets inputContentPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Maximum allowed message length (characters).
  static const int maxMessageLength = 4000;

  /// Show character counter when remaining chars drops below this threshold.
  static const int _counterThreshold = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = _conversationL10n(context);
    final draftLength = state.draft.length;
    final isOverLimit = draftLength > maxMessageLength;
    final showCounter = draftLength > maxMessageLength - _counterThreshold;
    final canSend = state.canSend && !isOverLimit;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.replyToMessage != null) ...[
              _ReplyPreviewBanner(
                key: const ValueKey('composer-reply-preview'),
                message: state.replyToMessage!,
                onDismiss: onClearReply,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (state.sendFailure != null) ...[
              Text(
                state.sendFailure?.userMessage(l10n) ??
                    l10n.conversationComposerSendFailedFallback,
                key: const ValueKey('composer-send-error'),
                style: TextStyle(
                  color: colors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (state.pendingAttachments.isNotEmpty) ...[
              Wrap(
                key: const ValueKey('composer-pending-attachments'),
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var i = 0; i < state.pendingAttachments.length; i++)
                    _AttachmentChip(
                      key: ValueKey('pending-attachment-$i'),
                      name: state.pendingAttachments[i].name,
                      progress: state.uploadProgress[i],
                      onDelete: state.uploadProgress.containsKey(i)
                          ? null
                          : () => onRemoveAttachment(i),
                      onCancel: state.uploadProgress.containsKey(i)
                          ? () => onCancelUpload(i)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (isRecording)
              VoiceRecorderWidget(
                key: const ValueKey('composer-voice-recorder'),
                onSend: onSendRecording,
                onCancel: onCancelRecording,
              )
            else ...[
              FormattingToolbar(
                controller: controller,
                visible: isFormattingToolbarVisible,
                focusNode: focusNode,
                onChanged: onChanged,
              ),
              Row(
                children: [
                  Container(
                    key: const ValueKey('composer-attach'),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.attach_file, size: 20),
                      padding: EdgeInsets.zero,
                      tooltip: l10n.conversationComposerAttachTooltip,
                      onPressed: state.isSending
                          ? null
                          : () => _showAttachOptions(context, ref),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    key: const ValueKey('composer-format-toggle'),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isFormattingToolbarVisible
                          ? colors.primaryLight
                          : colors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.text_format,
                        size: 20,
                        color:
                            isFormattingToolbarVisible ? colors.primary : null,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: l10n.conversationComposerFormattingTooltip,
                      onPressed: onToggleFormattingToolbar,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    key: const ValueKey('composer-emoji'),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isEmojiPickerVisible
                          ? colors.primaryLight
                          : colors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        size: 20,
                        color: isEmojiPickerVisible ? colors.primary : null,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: l10n.conversationComposerEmojiTooltip,
                      onPressed: onToggleEmojiPicker,
                    ),
                  ),
                  if (onToggleAsTask != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      key: const ValueKey('composer-task-toggle'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: asTask ? colors.primaryLight : colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.task_alt,
                          size: 20,
                          color: asTask ? colors.primary : null,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: l10n.conversationComposerTaskToggleTooltip,
                        onPressed: state.isSending ? null : onToggleAsTask,
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) => handleComposerKeyEvent(
                        node,
                        event,
                        enterToSend: enterToSend,
                        controller: controller,
                        canSend: canSend,
                        onSend: onSend,
                        onTextChanged: onChanged,
                      ),
                      child: TextField(
                        key: const ValueKey('composer-input'),
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onChanged,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: l10n.conversationComposerHint,
                          border: OutlineInputBorder(
                            borderRadius: inputBorderRadius,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: inputBorderRadius,
                            borderSide: BorderSide(color: colors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: inputBorderRadius,
                            borderSide:
                                BorderSide(color: colors.primary, width: 1.5),
                          ),
                          contentPadding: inputContentPadding,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (canSend)
                    Container(
                      key: const ValueKey('composer-send'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          state.isSending ? Icons.hourglass_top : Icons.send,
                          size: 20,
                          color: colors.primaryForeground,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: l10n.composerSendTooltip,
                        onPressed: state.isSending ? null : onSend,
                      ),
                    )
                  else
                    Container(
                      key: const ValueKey('composer-mic'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.mic,
                          size: 20,
                          color: colors.textTertiary,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: l10n.composerVoiceMessageTooltip,
                        onPressed: state.isSending ? null : onMicTap,
                      ),
                    ),
                ],
              ),
            ],
            if (showCounter) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  key: const ValueKey('composer-char-counter'),
                  isOverLimit
                      ? l10n.composerMessageTooLong
                      : l10n.composerCharacterCount(
                          draftLength, maxMessageLength),
                  style: AppTypography.caption.copyWith(
                    color: isOverLimit ? colors.error : colors.textTertiary,
                  ),
                ),
              ),
            ],
            if (isEmojiPickerVisible)
              SizedBox(
                key: const ValueKey('composer-emoji-picker'),
                height: 256,
                child: EmojiPicker(
                  textEditingController: controller,
                  onEmojiSelected: (_, __) {
                    // Sync controller text to store draft so send() sees
                    // emoji insertions made by the package.
                    onChanged(controller.text);
                  },
                  config: Config(
                    height: 256,
                    checkPlatformCompatibility: false,
                    emojiViewConfig: EmojiViewConfig(
                      emojiSizeMax: 28,
                      backgroundColor: colors.surface,
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      backgroundColor: colors.surface,
                      indicatorColor: colors.primary,
                      iconColorSelected: colors.primary,
                      recentTabBehavior: RecentTabBehavior.NONE,
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      showBackspaceButton: false,
                      showSearchViewButton: true,
                    ),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: colors.surface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAttachOptions(BuildContext context, WidgetRef ref) async {
    final colors = Theme.of(context).extension<AppColors>()!;
    final option = await showModalBottomSheet<_AttachOption>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: colors.text),
              title: Text(_conversationL10n(context)
                  .conversationComposerAttachPhotoVideo),
              onTap: () => Navigator.pop(ctx, _AttachOption.gallery),
            ),
            ListTile(
              key: const ValueKey('attach-camera'),
              leading: Icon(Icons.camera_alt, color: colors.text),
              title: Text(
                  _conversationL10n(context).conversationComposerAttachCamera),
              onTap: () => Navigator.pop(ctx, _AttachOption.camera),
            ),
            ListTile(
              leading: Icon(Icons.insert_drive_file, color: colors.text),
              title: Text(
                  _conversationL10n(context).conversationComposerAttachFile),
              onTap: () => Navigator.pop(ctx, _AttachOption.file),
            ),
          ],
        ),
      ),
    );
    if (option == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = _conversationL10n(context);
    switch (option) {
      case _AttachOption.gallery:
        await _pickGallery(messenger, l10n);
      case _AttachOption.camera:
        await _pickCamera(ref, messenger, l10n);
      case _AttachOption.file:
        await _pickFile(messenger, l10n);
    }
  }

  Future<void> _pickGallery(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) return;
    if (!await _isWithinFileSizeLimit(
      messenger,
      l10n,
      path: path,
      fallbackSizeBytes: file.size,
    )) {
      return;
    }
    final extension = file.extension ?? '';
    final mimeType = _mimeFromExtension(extension);
    onPickAttachment(PendingAttachment(
      path: path,
      name: file.name,
      mimeType: mimeType,
    ));
  }

  Future<void> _pickCamera(
    WidgetRef ref,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      final name = photo.name;
      final photoLength = await photo.length();
      if (!await _isWithinFileSizeLimit(
        messenger,
        l10n,
        path: photo.path,
        fallbackSizeBytes: photoLength,
      )) {
        return;
      }
      final ext = name.split('.').last;
      final mimeType = _mimeFromExtension(ext);
      onPickAttachment(PendingAttachment(
        path: photo.path,
        name: name,
        mimeType: mimeType,
      ));
    } on Exception catch (e) {
      ref
          .read(diagnosticsCollectorProvider)
          .error('Composer', 'Camera capture failed: $e');
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('camera-error-snackbar'),
          content: Text(
            l10n.conversationComposerCameraUnavailable,
          ),
        ),
      );
    }
  }

  Future<void> _pickFile(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) return;
    if (!await _isWithinFileSizeLimit(
      messenger,
      l10n,
      path: path,
      fallbackSizeBytes: file.size,
    )) {
      return;
    }
    final extension = file.extension ?? '';
    final mimeType = _mimeFromExtension(extension);
    onPickAttachment(PendingAttachment(
      path: path,
      name: file.name,
      mimeType: mimeType,
    ));
  }

  Future<bool> _isWithinFileSizeLimit(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n, {
    required String path,
    required int fallbackSizeBytes,
  }) async {
    final size = _fileSize(path, fallbackSizeBytes);
    if (size <= _maxAttachmentSizeBytes) return true;
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('attachment-size-error-snackbar'),
        content: Text(l10n.composerFileTooLarge),
      ),
    );
    return false;
  }

  int _fileSize(String path, int fallbackSizeBytes) {
    if (fallbackSizeBytes > _maxAttachmentSizeBytes) {
      return fallbackSizeBytes;
    }
    final file = File(path);
    try {
      if (file.existsSync()) {
        return file.lengthSync();
      }
    } on FileSystemException {
      return fallbackSizeBytes;
    }
    return fallbackSizeBytes;
  }

  static String _mimeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt' => 'text/plain',
      'mp4' => 'video/mp4',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'application/octet-stream',
    };
  }
}

const _maxAttachmentSizeBytes = 50 * 1024 * 1024;

enum _AttachOption { gallery, camera, file }

/// A chip that shows the attachment filename. When an upload is in progress,
/// overlays a progress indicator and replaces the delete button with cancel.
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    super.key,
    required this.name,
    this.progress,
    this.onDelete,
    this.onCancel,
  });

  final String name;

  /// Null when not uploading; 0.0-1.0 during upload.
  final double? progress;
  final VoidCallback? onDelete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isUploading = progress != null;
    final percent = isUploading ? (progress! * 100).round() : 0;

    return Chip(
      avatar: isUploading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                key: const ValueKey('attachment-upload-indicator'),
                value: progress,
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          : const Icon(Icons.attach_file, size: 16),
      label: Text(
        isUploading ? '$name · $percent%' : name,
        overflow: TextOverflow.ellipsis,
      ),
      deleteIcon: Icon(
        isUploading ? Icons.close : Icons.cancel,
        size: 16,
      ),
      onDeleted: isUploading ? onCancel : onDelete,
    );
  }
}

/// Banner shown above the composer when replying to a message.
class _ReplyPreviewBanner extends StatelessWidget {
  const _ReplyPreviewBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final ConversationMessageSummary message;
  final VoidCallback onDismiss;

  /// Hoisted BorderRadius for reply preview — avoids per-build allocation
  /// (Scan #46 PR B).
  static final _borderRadius = BorderRadius.circular(AppSpacing.radiusSm);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colors.primary, width: 3),
        ),
        color: colors.surfaceAlt,
        borderRadius: _borderRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.localizedSenderLabel(l10n),
                  style: AppTypography.label.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: context.l10n.replyPreviewDismissSemantics,
            child: GestureDetector(
              key: const ValueKey('reply-preview-dismiss'),
              onTap: onDismiss,
              child: Icon(
                Icons.close,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
