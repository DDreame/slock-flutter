import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_state.dart';

/// The kind of source for an unread item.
enum HomeUnreadKind { thread, channel, directMessage }

/// A single unread item shown in the Home Unread section.
///
/// Aggregates thread, channel, and DM unreads into a common
/// shape for sorting and display.
@immutable
class HomeUnreadItem {
  const HomeUnreadItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.unreadCount,
    this.sourceLabel,
    this.preview,
    this.lastActivityAt,
    this.threadRouteTarget,
    this.channelScopeId,
    this.dmScopeId,
  });

  /// Build from a [ThreadInboxItem] with unreadCount > 0.
  ///
  /// Pass [parentChannelName] to include the parent channel
  /// in the [sourceLabel] (e.g. "#general · Thread title").
  factory HomeUnreadItem.fromThread(
    ThreadInboxItem thread, {
    String? parentChannelName,
  }) {
    final title = thread.resolvedTitle;
    final label =
        parentChannelName != null ? '#$parentChannelName \u00b7 $title' : title;
    return HomeUnreadItem(
      kind: HomeUnreadKind.thread,
      id: 'thread:${thread.routeTarget.parentMessageId}',
      title: title,
      unreadCount: thread.unreadCount,
      sourceLabel: label,
      preview: thread.preview,
      lastActivityAt: thread.lastReplyAt,
      threadRouteTarget: thread.routeTarget,
    );
  }

  /// Build from a [HomeChannelSummary] + unread count.
  factory HomeUnreadItem.fromChannel(
    HomeChannelSummary channel,
    int unreadCount,
  ) {
    return HomeUnreadItem(
      kind: HomeUnreadKind.channel,
      id: 'channel:${channel.scopeId.value}',
      title: channel.name,
      unreadCount: unreadCount,
      sourceLabel: '#${channel.name}',
      preview: channel.lastMessagePreview,
      lastActivityAt: channel.lastActivityAt,
      channelScopeId: channel.scopeId,
    );
  }

  /// Build from a [HomeDirectMessageSummary] + unread count.
  factory HomeUnreadItem.fromDirectMessage(
    HomeDirectMessageSummary dm,
    int unreadCount,
  ) {
    return HomeUnreadItem(
      kind: HomeUnreadKind.directMessage,
      id: 'dm:${dm.scopeId.value}',
      title: dm.title,
      unreadCount: unreadCount,
      sourceLabel: dm.title,
      preview: dm.lastMessagePreview,
      lastActivityAt: dm.lastActivityAt,
      dmScopeId: dm.scopeId,
    );
  }

  final HomeUnreadKind kind;
  final String id;
  final String title;
  final int unreadCount;

  /// Formatted display label for the unread source.
  ///
  /// Thread: "#channelName · threadTitle"
  /// Channel: "#channelName"
  /// DM: "peerName"
  final String? sourceLabel;
  final String? preview;
  final DateTime? lastActivityAt;

  /// Non-null when [kind] is [HomeUnreadKind.thread].
  final ThreadRouteTarget? threadRouteTarget;

  /// Non-null when [kind] is [HomeUnreadKind.channel].
  final ChannelScopeId? channelScopeId;

  /// Non-null when [kind] is [HomeUnreadKind.directMessage].
  final DirectMessageScopeId? dmScopeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeUnreadItem &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          id == other.id &&
          title == other.title &&
          unreadCount == other.unreadCount &&
          sourceLabel == other.sourceLabel &&
          preview == other.preview &&
          lastActivityAt == other.lastActivityAt;

  @override
  int get hashCode => Object.hash(
        kind,
        id,
        title,
        unreadCount,
        sourceLabel,
        preview,
        lastActivityAt,
      );
}

/// Build a sorted list of [HomeUnreadItem]s from the provided data.
///
/// Shared by the Home unread card and the full unread-list page.
List<HomeUnreadItem> buildUnreadItems({
  required List<ThreadInboxItem> threadItems,
  required List<HomeChannelSummary> channels,
  required List<HomeDirectMessageSummary> directMessages,
  required ChannelUnreadState unreadState,
}) {
  final items = <HomeUnreadItem>[];

  // Threads with unread > 0
  for (final thread in threadItems) {
    if (thread.unreadCount > 0) {
      String? parentName;
      for (final ch in channels) {
        if (ch.scopeId.value == thread.routeTarget.parentChannelId) {
          parentName = ch.name;
          break;
        }
      }
      items.add(
        HomeUnreadItem.fromThread(thread, parentChannelName: parentName),
      );
    }
  }

  // Channels with unread > 0
  for (final entry in unreadState.channelUnreadCounts.entries) {
    if (entry.value > 0) {
      HomeChannelSummary? channel;
      for (final ch in channels) {
        if (ch.scopeId == entry.key) {
          channel = ch;
          break;
        }
      }
      if (channel != null) {
        items.add(HomeUnreadItem.fromChannel(channel, entry.value));
      }
    }
  }

  // DMs with unread > 0
  for (final entry in unreadState.dmUnreadCounts.entries) {
    if (entry.value > 0) {
      HomeDirectMessageSummary? dm;
      for (final d in directMessages) {
        if (d.scopeId == entry.key) {
          dm = d;
          break;
        }
      }
      if (dm != null) {
        items.add(HomeUnreadItem.fromDirectMessage(dm, entry.value));
      }
    }
  }

  // Sort by last activity (most recent first), nulls last
  items.sort((a, b) {
    final aTime = a.lastActivityAt;
    final bTime = b.lastActivityAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });

  return items;
}
