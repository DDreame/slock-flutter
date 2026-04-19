import 'package:flutter/material.dart';

class MachinesPage extends StatelessWidget {
  final String serverId;

  const MachinesPage({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Machines')),
      body: Center(child: Text('Machines for server $serverId')),
    );
  }
}
