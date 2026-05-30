import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/snackbar_utils.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/data/available_channel.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Page listing public channels the user has not yet joined.
///
/// Each channel shows a "Join" button. After joining, the button switches to
/// a "Joined!" label and the channel becomes accessible from the home list.
class BrowseChannelsPage extends ConsumerStatefulWidget {
  const BrowseChannelsPage({super.key});

  @override
  ConsumerState<BrowseChannelsPage> createState() => _BrowseChannelsPageState();
}

class _BrowseChannelsPageState extends ConsumerState<BrowseChannelsPage> {
  List<AvailableChannel>? _channels;
  bool _isLoading = true;
  AppFailure? _failure;
  final Set<String> _joinedIds = {};
  final Set<String> _joiningIds = {};

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final channels = await ref
          .read(channelManagementRepositoryProvider)
          .loadAvailableChannels(serverId);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _isLoading = false;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = const UnknownFailure();
        _isLoading = false;
      });
    }
  }

  Future<void> _joinChannel(AvailableChannel channel) async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;
    if (_joiningIds.contains(channel.id)) return;

    setState(() => _joiningIds.add(channel.id));

    try {
      final scopeId = ChannelScopeId(serverId: serverId, value: channel.id);
      await ref
          .read(channelManagementStoreProvider.notifier)
          .joinChannel(scopeId);
      if (!mounted) return;
      setState(() {
        _joiningIds.remove(channel.id);
        _joinedIds.add(channel.id);
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _joiningIds.remove(channel.id));
      showAppSnackBar(
        context,
        failure.userMessage(context.l10n),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _joiningIds.remove(channel.id));
      showAppSnackBar(context, context.l10n.channelsBrowseJoinFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.channelsBrowseTitle),
      ),
      body: _buildBody(l10n, colors),
    );
  }

  Widget _buildBody(AppLocalizations l10n, AppColors colors) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_failure != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _failure!.userMessage(l10n),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _loadChannels,
                child: Text(l10n.homeRetry),
              ),
            ],
          ),
        ),
      );
    }

    final channels = _channels;
    if (channels == null || channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.channelsBrowseEmpty,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChannels,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.sm,
        ),
        itemCount: channels.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final channel = channels[index];
          return _BrowseChannelTile(
            channel: channel,
            isJoined: _joinedIds.contains(channel.id),
            isJoining: _joiningIds.contains(channel.id),
            onJoin: () => _joinChannel(channel),
          );
        },
      ),
    );
  }
}

class _BrowseChannelTile extends StatelessWidget {
  const _BrowseChannelTile({
    required this.channel,
    required this.isJoined,
    required this.isJoining,
    required this.onJoin,
  });

  final AvailableChannel channel;
  final bool isJoined;
  final bool isJoining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: colors.surfaceAlt,
        child: Text(
          '#',
          style: AppTypography.label.copyWith(color: colors.textSecondary),
        ),
      ),
      title: Text(
        channel.name,
        style: AppTypography.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: channel.description != null && channel.description!.isNotEmpty
          ? Text(
              channel.description!,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: _buildTrailing(l10n, colors),
    );
  }

  Widget _buildTrailing(AppLocalizations l10n, AppColors colors) {
    if (isJoined) {
      return Text(
        l10n.channelsBrowseJoined,
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      );
    }
    if (isJoining) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return FilledButton.tonal(
      onPressed: onJoin,
      child: Text(l10n.channelsBrowseJoin),
    );
  }
}
