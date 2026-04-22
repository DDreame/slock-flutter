import 'package:flutter/material.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';

class MemberListItem extends StatelessWidget {
  const MemberListItem({
    super.key,
    required this.member,
    required this.onTap,
    required this.onMessage,
    this.isOpeningDirectMessage = false,
  });

  final MemberProfile member;
  final VoidCallback onTap;
  final VoidCallback onMessage;
  final bool isOpeningDirectMessage;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (member.presence != null) member.presence,
      if (member.username != null) '@${member.username}',
      member.id,
    ].join(' • ');

    return ListTile(
      key: ValueKey('member-${member.id}'),
      leading: ProfileAvatar(
        displayName: member.displayName,
        avatarUrl: member.avatarUrl,
        radius: 20,
      ),
      title: Text(member.displayName),
      subtitle: Text(subtitle),
      trailing: IconButton(
        key: ValueKey('member-message-${member.id}'),
        icon: isOpeningDirectMessage
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chat_bubble_outline),
        onPressed: isOpeningDirectMessage ? null : onMessage,
        tooltip: 'Message',
      ),
      onTap: onTap,
    );
  }
}
