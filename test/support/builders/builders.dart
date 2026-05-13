import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ---------------------------------------------------------------------------
// ServerBuilder
// ---------------------------------------------------------------------------

/// Builds a [ServerScopeId] + [ServerSummary] pair for test fixtures.
class ServerBuilder {
  ServerBuilder([String id = 'server-1'])
      : _id = id,
        _name = id;

  final String _id;
  String _name;
  String _role = 'member';

  ServerBuilder withName(String name) {
    _name = name;
    return this;
  }

  ServerBuilder withRole(String role) {
    _role = role;
    return this;
  }

  ServerScopeId get scopeId => ServerScopeId(_id);

  ServerSummary build() => ServerSummary(
        id: _id,
        name: _name,
        role: _role,
      );
}

// ---------------------------------------------------------------------------
// ChannelBuilder
// ---------------------------------------------------------------------------

/// Builds a [HomeChannelSummary] for test fixtures.
class ChannelBuilder {
  ChannelBuilder(String id, {String? serverId})
      : _id = id,
        _serverId = ServerScopeId(serverId ?? 'server-1'),
        _name = id;

  final String _id;
  final ServerScopeId _serverId;
  String _name;
  String? _lastMessageId;
  String? _lastMessagePreview;
  DateTime? _lastActivityAt;
  bool _isPrivate = false;

  ChannelBuilder withName(String name) {
    _name = name;
    return this;
  }

  ChannelBuilder withPreview(String preview, {String? messageId}) {
    _lastMessagePreview = preview;
    _lastMessageId = messageId ?? 'msg-$_id';
    return this;
  }

  ChannelBuilder withActivity(DateTime activityAt) {
    _lastActivityAt = activityAt;
    return this;
  }

  ChannelBuilder withPrivate([bool value = true]) {
    _isPrivate = value;
    return this;
  }

  ChannelScopeId get scopeId => ChannelScopeId(serverId: _serverId, value: _id);

  HomeChannelSummary build() => HomeChannelSummary(
        scopeId: scopeId,
        name: _name,
        lastMessageId: _lastMessageId,
        lastMessagePreview: _lastMessagePreview,
        lastActivityAt: _lastActivityAt,
        isPrivate: _isPrivate,
      );
}

// ---------------------------------------------------------------------------
// DmBuilder
// ---------------------------------------------------------------------------

/// Builds a [HomeDirectMessageSummary] for test fixtures.
class DmBuilder {
  DmBuilder(String id, {String? serverId})
      : _id = id,
        _serverId = ServerScopeId(serverId ?? 'server-1'),
        _title = id;

  final String _id;
  final ServerScopeId _serverId;
  String _title;
  String? _lastMessageId;
  String? _lastMessagePreview;
  DateTime? _lastActivityAt;
  bool _isAgent = false;
  String? _peerId;

  DmBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  DmBuilder withPreview(String preview, {String? messageId}) {
    _lastMessagePreview = preview;
    _lastMessageId = messageId ?? 'msg-$_id';
    return this;
  }

  DmBuilder withActivity(DateTime activityAt) {
    _lastActivityAt = activityAt;
    return this;
  }

  DmBuilder asAgent({String? peerId}) {
    _isAgent = true;
    _peerId = peerId;
    return this;
  }

  DirectMessageScopeId get scopeId =>
      DirectMessageScopeId(serverId: _serverId, value: _id);

  HomeDirectMessageSummary build() => HomeDirectMessageSummary(
        scopeId: scopeId,
        title: _title,
        lastMessageId: _lastMessageId,
        lastMessagePreview: _lastMessagePreview,
        lastActivityAt: _lastActivityAt,
        isAgent: _isAgent,
        peerId: _peerId,
      );
}

// ---------------------------------------------------------------------------
// InboxItemBuilder
// ---------------------------------------------------------------------------

/// Builds an [InboxItem] for test fixtures.
class InboxItemBuilder {
  InboxItemBuilder(
    String channelId, {
    InboxItemKind kind = InboxItemKind.channel,
  })  : _channelId = channelId,
        _kind = kind;

  final String _channelId;
  final InboxItemKind _kind;
  String? _channelName;
  int _unreadCount = 0;
  String? _preview;
  String? _senderName;
  DateTime? _lastActivityAt;
  String? _threadChannelId;
  String? _parentChannelId;
  String? _parentMessageId;

  InboxItemBuilder withName(String name) {
    _channelName = name;
    return this;
  }

  InboxItemBuilder withUnread(int count) {
    _unreadCount = count;
    return this;
  }

  InboxItemBuilder withPreview(String preview, {String? senderName}) {
    _preview = preview;
    _senderName = senderName;
    return this;
  }

  InboxItemBuilder withActivity(DateTime activityAt) {
    _lastActivityAt = activityAt;
    return this;
  }

  InboxItemBuilder withThread({
    required String threadChannelId,
    required String parentChannelId,
    required String parentMessageId,
  }) {
    _threadChannelId = threadChannelId;
    _parentChannelId = parentChannelId;
    _parentMessageId = parentMessageId;
    return this;
  }

  InboxItem build() => InboxItem(
        kind: _kind,
        channelId: _channelId,
        channelName: _channelName ?? _channelId,
        unreadCount: _unreadCount,
        preview: _preview,
        senderName: _senderName,
        lastActivityAt: _lastActivityAt,
        threadChannelId: _threadChannelId,
        parentChannelId: _parentChannelId,
        parentMessageId: _parentMessageId,
      );
}

// ---------------------------------------------------------------------------
// TaskBuilder
// ---------------------------------------------------------------------------

/// Builds a [TaskItem] for test fixtures.
class TaskBuilder {
  TaskBuilder(String id, {int? taskNumber})
      : _id = id,
        _taskNumber = taskNumber ?? 1;

  final String _id;
  final int _taskNumber;
  String _title = 'Test Task';
  String _status = 'todo';
  String _channelId = 'ch-1';
  String _channelType = 'channel';
  String? _messageId;
  String? _claimedById;
  String? _claimedByName;
  String _createdById = 'user-1';
  String _createdByName = 'Tester';
  String _createdByType = 'user';
  DateTime _createdAt = DateTime(2026);

  TaskBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  TaskBuilder withStatus(String status) {
    _status = status;
    return this;
  }

  TaskBuilder inChannel(String channelId, {String type = 'channel'}) {
    _channelId = channelId;
    _channelType = type;
    return this;
  }

  TaskBuilder withMessage(String messageId) {
    _messageId = messageId;
    return this;
  }

  TaskBuilder claimedBy(String userId, {String name = 'Claimer'}) {
    _claimedById = userId;
    _claimedByName = name;
    return this;
  }

  TaskBuilder createdBy(
    String userId, {
    String name = 'Creator',
    String type = 'user',
  }) {
    _createdById = userId;
    _createdByName = name;
    _createdByType = type;
    return this;
  }

  TaskBuilder createdAt(DateTime dateTime) {
    _createdAt = dateTime;
    return this;
  }

  TaskItem build() => TaskItem(
        id: _id,
        taskNumber: _taskNumber,
        title: _title,
        status: _status,
        channelId: _channelId,
        channelType: _channelType,
        messageId: _messageId,
        claimedById: _claimedById,
        claimedByName: _claimedByName,
        createdById: _createdById,
        createdByName: _createdByName,
        createdByType: _createdByType,
        createdAt: _createdAt,
      );
}

// ---------------------------------------------------------------------------
// AgentBuilder
// ---------------------------------------------------------------------------

/// Builds an [AgentItem] for test fixtures.
class AgentBuilder {
  AgentBuilder(String id)
      : _id = id,
        _name = id;

  final String _id;
  String _name;
  String _model = 'claude-sonnet';
  final String _runtime = 'claude-code';
  String _status = 'active';
  String _activity = 'online';
  String? _displayName;
  String? _description;
  String? _machineId;
  String? _activityDetail;

  AgentBuilder withName(String name) {
    _name = name;
    return this;
  }

  AgentBuilder withModel(String model) {
    _model = model;
    return this;
  }

  AgentBuilder withStatus(String status) {
    _status = status;
    return this;
  }

  AgentBuilder withActivity(String activity, {String? detail}) {
    _activity = activity;
    _activityDetail = detail;
    return this;
  }

  AgentBuilder withDisplayName(String displayName) {
    _displayName = displayName;
    return this;
  }

  AgentBuilder withDescription(String description) {
    _description = description;
    return this;
  }

  AgentBuilder onMachine(String machineId) {
    _machineId = machineId;
    return this;
  }

  AgentItem build() => AgentItem(
        id: _id,
        name: _name,
        model: _model,
        runtime: _runtime,
        status: _status,
        activity: _activity,
        displayName: _displayName,
        description: _description,
        machineId: _machineId,
        activityDetail: _activityDetail,
      );
}

// ---------------------------------------------------------------------------
// MessageBuilder (for RealtimeEventEnvelope payloads)
// ---------------------------------------------------------------------------

/// Builds a message payload [Map] suitable for [RealtimeEventEnvelope].
class MessagePayloadBuilder {
  MessagePayloadBuilder(String id)
      : _id = id,
        _content = 'Test message';

  final String _id;
  String _content;
  String _senderId = 'user-1';
  String _senderName = 'Tester';
  String _channelId = 'ch-1';

  MessagePayloadBuilder withContent(String content) {
    _content = content;
    return this;
  }

  MessagePayloadBuilder from(String senderId, {String? name}) {
    _senderId = senderId;
    _senderName = name ?? senderId;
    return this;
  }

  MessagePayloadBuilder inChannel(String channelId) {
    _channelId = channelId;
    return this;
  }

  Map<String, Object> build() => {
        'id': _id,
        'content': _content,
        'senderId': _senderId,
        'senderName': _senderName,
        'channelId': _channelId,
      };
}
