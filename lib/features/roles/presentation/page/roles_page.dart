import 'package:flutter/material.dart';

class RolesPage extends StatelessWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roles')),
      body: const Center(
        key: ValueKey('roles-placeholder'),
        child: Text('Roles management coming soon.'),
      ),
    );
  }
}
