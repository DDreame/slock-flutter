import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/presentation/widgets/member_list_item.dart';

class MembersPage extends StatelessWidget {
  MembersPage({super.key, required String serverId})
      : _serverId = ServerScopeId(serverId);

  final ServerScopeId _serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentMembersServerIdProvider.overrideWithValue(_serverId),
      ],
      child: const _MembersScreen(),
    );
  }
}

class _MembersScreen extends ConsumerStatefulWidget {
  const _MembersScreen();

  @override
  ConsumerState<_MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<_MembersScreen> {
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
    final serverId = ref.read(currentMembersServerIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: switch (state.status) {
        MemberListStatus.initial || MemberListStatus.loading => const Center(
            key: ValueKey('members-loading'),
            child: CircularProgressIndicator(),
          ),
        MemberListStatus.failure => Center(
            key: const ValueKey('members-error'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.failure?.message ?? 'Could not load members.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.read(memberListStoreProvider.notifier).load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        MemberListStatus.success when state.members.isEmpty => const Center(
            key: ValueKey('members-empty'),
            child: Text('No members found.'),
          ),
        MemberListStatus.success => ListView.builder(
            key: const ValueKey('members-list'),
            itemCount: state.members.length,
            itemBuilder: (context, index) {
              final member = state.members[index];
              return MemberListItem(
                member: member,
                isOpeningDirectMessage: state.isOpeningDirectMessage(member.id),
                onTap: () => context.go(
                  '/servers/${serverId.value}/profile/${member.id}',
                ),
                onMessage: () => _openDirectMessage(context, member.id),
              );
            },
          ),
      },
    );
  }

  Future<void> _openDirectMessage(BuildContext context, String userId) async {
    final serverId = ref.read(currentMembersServerIdProvider);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final channelId = await ref
          .read(memberListStoreProvider.notifier)
          .openDirectMessage(userId);
      if (!mounted) {
        return;
      }
      router.go('/servers/${serverId.value}/dms/$channelId');
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Failed to open direct message.'),
        ),
      );
    }
  }
}
