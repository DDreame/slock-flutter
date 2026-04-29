import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';

class InviteLandingPage extends ConsumerStatefulWidget {
  const InviteLandingPage({required this.token, super.key});

  final String token;

  @override
  ConsumerState<InviteLandingPage> createState() => _InviteLandingPageState();
}

class _InviteLandingPageState extends ConsumerState<InviteLandingPage> {
  bool _isJoining = false;
  String? _errorMessage;

  Future<void> _acceptInvite() async {
    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(serverListStoreProvider.notifier)
          .acceptInvite(widget.token);
      if (!mounted) return;
      context.go('/home');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _errorMessage = failure.message ?? 'Failed to join workspace.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _errorMessage = 'Failed to join workspace.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Workspace')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isJoining
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Joining workspace...'),
                  ],
                )
              : _errorMessage != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _acceptInvite,
                          child: const Text('Retry'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go('/home'),
                          child: const Text('Go home'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mail_outline, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'You have been invited to join a workspace.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const ValueKey('invite-accept'),
                          onPressed: _acceptInvite,
                          child: const Text('Join workspace'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go('/home'),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
