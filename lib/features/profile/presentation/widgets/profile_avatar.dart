import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.radius = 40,
  });

  final String displayName;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    if (avatarUrl != null) {
      return CircleAvatar(
        key: const ValueKey('profile-avatar-image'),
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
        child: const SizedBox.shrink(),
      );
    }

    return CircleAvatar(
      key: const ValueKey('profile-avatar-initials'),
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        initials,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
