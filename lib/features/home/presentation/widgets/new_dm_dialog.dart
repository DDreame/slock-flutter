import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

class NewDmDialog extends StatelessWidget {
  const NewDmDialog({super.key, required this.serverId});

  final ServerScopeId serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
      ],
      child: _NewDmDialogContent(serverId: serverId),
    );
  }
}

class _NewDmDialogContent extends ConsumerStatefulWidget {
  const _NewDmDialogContent({required this.serverId});

  final ServerScopeId serverId;

  @override
  ConsumerState<_NewDmDialogContent> createState() =>
      _NewDmDialogContentState();
}

class _NewDmDialogContentState extends ConsumerState<_NewDmDialogContent> {
  String? _openingUserId;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(memberListStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberListStoreProvider);

    return AlertDialog(
      key: const ValueKey('new-dm-dialog'),
      title: const Text('New message'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: switch (state.status) {
          MemberListStatus.initial ||
          MemberListStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          MemberListStatus.failure => _ErrorContent(
              message: state.failure?.message ?? 'Failed to load members.',
              onRetry: ref.read(memberListStoreProvider.notifier).load,
            ),
          MemberListStatus.success => _MemberList(
              members: state.members.where((m) => !m.isSelf).toList(),
              openingUserId: _openingUserId,
              onSelect: _openDirectMessage,
            ),
        },
      ),
      actions: [
        TextButton(
          onPressed:
              _openingUserId != null ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _openDirectMessage(MemberProfile member) async {
    setState(() => _openingUserId = member.id);
    try {
      final channelId =
          await ref.read(memberRepositoryProvider).openDirectMessage(
                widget.serverId,
                userId: member.id,
              );
      if (!mounted) return;
      Navigator.of(context).pop(channelId);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _openingUserId = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to open conversation.'),
          ),
        );
    }
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.openingUserId,
    required this.onSelect,
  });

  final List<MemberProfile> members;
  final String? openingUserId;
  final void Function(MemberProfile) onSelect;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(child: Text('No members available.'));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final isOpening = openingUserId == member.id;
        return ListTile(
          key: ValueKey('dm-member-${member.id}'),
          leading: CircleAvatar(
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Text(member.displayName.characters.first.toUpperCase())
                : null,
          ),
          title: Text(member.displayName),
          trailing: isOpening
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          enabled: openingUserId == null,
          onTap: () => onSelect(member),
        );
      },
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
