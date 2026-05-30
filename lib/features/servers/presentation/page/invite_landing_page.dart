import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/errors/app_failure_user_message.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

class InviteLandingPage extends ConsumerStatefulWidget {
  const InviteLandingPage({required this.token, super.key});

  final String token;

  @override
  ConsumerState<InviteLandingPage> createState() => _InviteLandingPageState();
}

class _InviteLandingPageState extends ConsumerState<InviteLandingPage> {
  bool _isLoadingPreview = true;
  bool _isJoining = false;
  String? _errorMessage;
  AcceptInviteResult? _result;
  InviteInfo? _inviteInfo;

  /// Non-blocking warning from preview fetch (e.g. rate limit).
  String? _previewWarning;

  /// When the preview fetch fails with 404/expired, we block accept entirely.
  bool _isInviteInvalid = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final repo = ref.read(serverListRepositoryProvider);
      final info = await repo.getInviteInfo(widget.token);
      if (!mounted) return;
      setState(() {
        _inviteInfo = info;
        _isLoadingPreview = false;
      });
    } on NotFoundFailure {
      if (!mounted) return;
      setState(() {
        _isLoadingPreview = false;
        _isInviteInvalid = true;
        _errorMessage = context.l10n.serversInvitePreviewExpired;
      });
    } on RateLimitFailure {
      if (!mounted) return;
      setState(() {
        _isLoadingPreview = false;
        _previewWarning = context.l10n.serversInvitePreviewRateLimit;
      });
    } on AppFailure {
      // Non-fatal: show generic description without preview info.
      if (!mounted) return;
      setState(() {
        _isLoadingPreview = false;
      });
    } catch (_) {
      // Non-fatal: show generic description without preview info.
      if (!mounted) return;
      setState(() {
        _isLoadingPreview = false;
      });
    }
  }

  Future<void> _acceptInvite() async {
    if (_isJoining) return;
    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(serverListStoreProvider.notifier)
          .acceptInvite(widget.token);
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _result = result;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _errorMessage = failure.userMessage(context.l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _errorMessage = context.l10n.serversInviteFailedFallback;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.serversInviteTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isJoining) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.l10n.serversInviteJoining),
        ],
      );
    }

    if (_result != null) {
      return _SuccessView(
        result: _result!,
        onContinue: () => context.go('/home'),
      );
    }

    if (_isLoadingPreview) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            key: ValueKey('invite-preview-loading'),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.serversInvitePreviewLoading),
        ],
      );
    }

    // Error state that blocks accept (invalid/expired invite).
    if (_isInviteInvalid) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            key: const ValueKey('invite-error-message'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/home'),
            child: Text(context.l10n.serversInviteGoHome),
          ),
        ],
      );
    }

    // Accept-attempt error (retry-able).
    if (_errorMessage != null) {
      return Column(
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
            onPressed: _isJoining ? null : _acceptInvite,
            child: Text(context.l10n.serversInviteRetry),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/home'),
            child: Text(context.l10n.serversInviteGoHome),
          ),
        ],
      );
    }

    // Preview state: show workspace info (if available) + accept button.
    final info = _inviteInfo;
    final warning = _previewWarning;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mail_outline, size: 48),
        const SizedBox(height: 16),
        if (warning != null) ...[
          Text(
            warning,
            key: const ValueKey('invite-preview-warning'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 12),
        ] else if (info != null) ...[
          Text(
            context.l10n.serversInvitePreviewDescription,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            info.workspaceName,
            key: const ValueKey('invite-workspace-name'),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (info.memberCount != null) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.serversInvitePreviewMembers(info.memberCount!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ] else
          Text(
            context.l10n.serversInviteDescription,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('invite-accept'),
          onPressed: _isJoining ? null : _acceptInvite,
          child: Text(context.l10n.serversInviteAccept),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go('/home'),
          child: Text(context.l10n.serversInviteCancel),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.result, required this.onContinue});

  final AcceptInviteResult result;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final name = result.workspaceName;
    final l10n = context.l10n;
    final message = name != null
        ? l10n.serversInviteSuccessNamed(name)
        : l10n.serversInviteSuccessGeneric;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          key: const ValueKey('invite-success-message'),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('invite-continue'),
          onPressed: onContinue,
          child: Text(l10n.serversInviteContinue),
        ),
      ],
    );
  }
}
