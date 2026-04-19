import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Text(userId != null ? 'User $userId' : 'My Profile'),
      ),
    );
  }
}
