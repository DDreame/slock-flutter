import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/widgets/share_preview_card.dart';

/// Whitespace splitter for avatar-initials extraction in the share picker.
///
/// Promoted from a per-call allocation inside [_DmTile._initials]
/// to a module-level constant, avoiding [RegExp] compilation on every row build.
@visibleForTesting
final sharePickerInitialsRegex = RegExp(r'\s+');

/// Identifies a conversation the user selected as a share target.
@immutable
class ShareTarget {
  const ShareTarget._({
    required this.serverId,
    required this.scopeId,
    required this.name,
    required this.isChannel,
  });

  factory ShareTarget.channel(ChannelScopeId scopeId, String name) {
    return ShareTarget._(
      serverId: scopeId.serverId,
      scopeId: scopeId.value,
      name: name,
      isChannel: true,
    );
  }

  factory ShareTarget.directMessage(
    DirectMessageScopeId scopeId,
    String name,
  ) {
    return ShareTarget._(
      serverId: scopeId.serverId,
      scopeId: scopeId.value,
      name: name,
      isChannel: false,
    );
  }

  final ServerScopeId serverId;
  final String scopeId;
  final String name;
  final bool isChannel;
}

/// Full-screen picker listing available channels and DMs for sharing.
///
/// Uses [homeListStoreProvider] for the conversation list and shows
/// the pending [SharedContent] preview at the top.
class ShareTargetPickerPage extends ConsumerStatefulWidget {
  const ShareTargetPickerPage({
    super.key,
    required this.onTargetSelected,
    required this.onCancel,
  });

  final ValueChanged<ShareTarget> onTargetSelected;
  final VoidCallback onCancel;

  @override
  ConsumerState<ShareTargetPickerPage> createState() =>
      _ShareTargetPickerPageState();
}

class _ShareTargetPickerPageState extends ConsumerState<ShareTargetPickerPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final homeState = ref.watch(
      homeListStoreProvider.select(
        (s) => (
          status: s.status,
          pinnedChannels: s.pinnedChannels,
          channels: s.channels,
          pinnedDirectMessages: s.pinnedDirectMessages,
          directMessages: s.directMessages,
        ),
      ),
    );
    final sharedContent = ref.watch(shareIntentStoreProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        title: const Text('Share to...'),
      ),
      body: _buildBody(colors, homeState, sharedContent),
    );
  }

  Widget _buildBody(
    AppColors colors,
    ({
      HomeListStatus status,
      List<HomeChannelSummary> pinnedChannels,
      List<HomeChannelSummary> channels,
      List<HomeDirectMessageSummary> pinnedDirectMessages,
      List<HomeDirectMessageSummary> directMessages,
    }) homeState,
    SharedContent? sharedContent,
  ) {
    if (homeState.status == HomeListStatus.loading ||
        homeState.status == HomeListStatus.initial) {
      return const AppLoadingIndicator();
    }

    final allChannels = [
      ...homeState.pinnedChannels,
      ...homeState.channels,
    ];
    final allDms = [
      ...homeState.pinnedDirectMessages,
      ...homeState.directMessages,
    ];

    final lowerQuery = _query.toLowerCase();
    final filteredChannels = _query.isEmpty
        ? allChannels
        : allChannels
            .where(
              (ch) => ch.name.toLowerCase().contains(lowerQuery),
            )
            .toList();
    final filteredDms = _query.isEmpty
        ? allDms
        : allDms
            .where(
              (dm) => dm.title.toLowerCase().contains(lowerQuery),
            )
            .toList();

    return Column(
      children: [
        if (sharedContent != null && sharedContent.isNotEmpty)
          SharePreviewCard(content: sharedContent),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.sm,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search conversations...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (filteredChannels.isNotEmpty) ...[
                _SectionHeader(title: 'Channels', colors: colors),
                ...filteredChannels.map(
                  (ch) => _ChannelTile(
                    channel: ch,
                    colors: colors,
                    onTap: () => widget.onTargetSelected(
                      ShareTarget.channel(ch.scopeId, ch.name),
                    ),
                  ),
                ),
              ],
              if (filteredDms.isNotEmpty) ...[
                _SectionHeader(title: 'Direct Messages', colors: colors),
                ...filteredDms.map(
                  (dm) => _DmTile(
                    directMessage: dm,
                    colors: colors,
                    onTap: () => widget.onTargetSelected(
                      ShareTarget.directMessage(dm.scopeId, dm.title),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.colors});

  final String title;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: AppTypography.label.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.colors,
    required this.onTap,
  });

  final HomeChannelSummary channel;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.tag, size: 20, color: colors.textTertiary),
      title: Text(
        '# ${channel.name}',
        style: AppTypography.body.copyWith(color: colors.text),
      ),
      onTap: onTap,
    );
  }
}

class _DmTile extends StatelessWidget {
  const _DmTile({
    required this.directMessage,
    required this.colors,
    required this.onTap,
  });

  final HomeDirectMessageSummary directMessage;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: colors.primaryLight,
        child: Text(
          _initials(directMessage.title),
          style: AppTypography.label.copyWith(
            color: colors.primary,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(
        directMessage.title,
        style: AppTypography.body.copyWith(color: colors.text),
      ),
      onTap: onTap,
    );
  }

  static String _initials(String title) {
    final words = title.trim().split(sharePickerInitialsRegex);
    if (words.isEmpty || words[0].isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
