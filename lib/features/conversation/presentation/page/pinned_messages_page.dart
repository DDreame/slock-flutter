import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/pinned_messages_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

class PinnedMessagesPage extends ConsumerStatefulWidget {
  const PinnedMessagesPage({
    super.key,
    this.onMessageTap,
  });

  final void Function(String messageId)? onMessageTap;

  @override
  ConsumerState<PinnedMessagesPage> createState() => _PinnedMessagesPageState();
}

class _PinnedMessagesPageState extends ConsumerState<PinnedMessagesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(pinnedMessagesStoreProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pinnedMessagesStoreProvider);
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinned messages'),
      ),
      body: _buildBody(state, colors),
    );
  }

  Widget _buildBody(PinnedMessagesState state, AppColors colors) {
    switch (state.status) {
      case PinnedMessagesStatus.initial:
      case PinnedMessagesStatus.loading:
        return const Center(
          key: ValueKey('pinned-messages-loading'),
          child: CircularProgressIndicator(),
        );
      case PinnedMessagesStatus.failure:
        return Center(
          key: const ValueKey('pinned-messages-error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.failure?.userMessage(context.l10n) ??
                    context.l10n.errorUnknown,
                style: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                key: const ValueKey('pinned-messages-retry'),
                onPressed: () =>
                    ref.read(pinnedMessagesStoreProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case PinnedMessagesStatus.success:
        if (state.messages.isEmpty) {
          return Center(
            key: const ValueKey('pinned-messages-empty'),
            child: Text(
              'No pinned messages',
              style: AppTypography.body.copyWith(
                color: colors.textSecondary,
              ),
            ),
          );
        }
        return ListView.separated(
          key: const ValueKey('pinned-messages-list'),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: state.messages.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final message = state.messages[index];
            return _PinnedMessageTile(
              key: ValueKey('pinned-msg-${message.id}'),
              message: message,
              colors: colors,
              onTap: widget.onMessageTap != null
                  ? () => widget.onMessageTap!(message.id)
                  : null,
            );
          },
        );
    }
  }
}

class _PinnedMessageTile extends StatelessWidget {
  const _PinnedMessageTile({
    super.key,
    required this.message,
    required this.colors,
    this.onTap,
  });

  final ConversationMessageSummary message;
  final AppColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.push_pin,
        color: colors.primary,
        size: 20,
      ),
      title: Text(
        message.senderName ?? message.senderType,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        message.content,
        style: AppTypography.body.copyWith(color: colors.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
