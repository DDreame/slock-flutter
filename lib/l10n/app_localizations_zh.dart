// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Slock';

  @override
  String get splashTitle => 'Slock';

  @override
  String get splashSubtitle => '正在准备你的工作区……';

  @override
  String get loginTitle => '登录';

  @override
  String get loginEmailLabel => '邮箱';

  @override
  String get loginPasswordLabel => '密码';

  @override
  String get loginSubmitLabel => '登录';

  @override
  String get loginCreateAccountCta => '创建账号';

  @override
  String get loginForgotPasswordCta => '忘记密码？';

  @override
  String get loginEmailRequiredError => '请输入邮箱地址。';

  @override
  String get loginEmailInvalidError => '请输入有效的邮箱地址。';

  @override
  String get loginPasswordRequiredError => '请输入密码。';

  @override
  String get loginFailedFallback => '登录失败，请重试。';

  @override
  String get registerTitle => '注册';

  @override
  String get registerDisplayNameLabel => '显示名称';

  @override
  String get registerEmailLabel => '邮箱';

  @override
  String get registerPasswordLabel => '密码';

  @override
  String get registerSubmitLabel => '注册';

  @override
  String get registerAlreadyHaveAccountCta => '已有账号？去登录';

  @override
  String get registerDisplayNameRequiredError => '请输入显示名称。';

  @override
  String get registerEmailRequiredError => '请输入邮箱地址。';

  @override
  String get registerEmailInvalidError => '请输入有效的邮箱地址。';

  @override
  String get registerPasswordTooShortError => '密码长度至少为 8 个字符。';

  @override
  String get registerFailedFallback => '注册失败，请重试。';

  @override
  String get forgotPasswordTitle => '忘记密码';

  @override
  String get forgotPasswordSuccessTitle => '请检查你的邮箱';

  @override
  String get forgotPasswordSuccessMessage => '如果该邮箱已注册，重置链接已发送到你的收件箱。';

  @override
  String get forgotPasswordEmailLabel => '邮箱';

  @override
  String get forgotPasswordSubmitLabel => '重置密码';

  @override
  String get forgotPasswordBackToLogin => '返回登录';

  @override
  String get forgotPasswordEmailRequiredError => '请输入邮箱地址。';

  @override
  String get forgotPasswordEmailInvalidError => '请输入有效的邮箱地址。';

  @override
  String get forgotPasswordFailedFallback => '发送重置邮件失败，请重试。';

  @override
  String get resetPasswordTitle => '重置密码';

  @override
  String get resetPasswordCompletedMessage => '密码重置完成。你现在可以使用新密码登录。';

  @override
  String get resetPasswordNewPasswordLabel => '新密码';

  @override
  String get resetPasswordConfirmPasswordLabel => '确认新密码';

  @override
  String get resetPasswordSubmitLabel => '设置新密码';

  @override
  String get resetPasswordBackToLogin => '返回登录';

  @override
  String get resetPasswordLinkInvalidError => '重置链接缺失或无效。';

  @override
  String get resetPasswordTooShortError => '密码长度至少为 8 个字符。';

  @override
  String get resetPasswordMismatchError => '两次输入的密码不一致。';

  @override
  String get resetPasswordFailedFallback => '密码重置失败，链接可能已过期。';

  @override
  String get verifyEmailTitle => '验证邮箱';

  @override
  String get verifyEmailInstructions => '请验证你的邮箱以继续。';

  @override
  String get verifyEmailResentMessage => '验证邮件已重新发送，请查看收件箱。';

  @override
  String get verifyEmailResendButton => '重新发送验证邮件';

  @override
  String get verifyEmailTokenLabel => '验证码';

  @override
  String get verifyEmailSubmitLabel => '验证';

  @override
  String get verifyEmailSuccessMessage => '邮箱验证成功，你可以继续使用应用。';

  @override
  String get verifyEmailContinueButton => '继续使用 Slock';

  @override
  String get verifyEmailSignOut => '退出登录';

  @override
  String get verifyEmailBackToLogin => '返回登录';

  @override
  String get verifyEmailTokenRequiredError => '请输入验证码。';

  @override
  String get verifyEmailFailedFallback => '验证失败，链接可能已过期。';

  @override
  String get verifyEmailResendFailedFallback => '重新发送验证邮件失败。';

  @override
  String get navWorkspace => '首页';

  @override
  String get navChannels => '频道';

  @override
  String get navDms => '消息';

  @override
  String get navAgents => '智能体';

  @override
  String get agentsNewTooltip => '新建智能体';

  @override
  String get navSettings => '设置';

  @override
  String get homeWorkspaceConsole => '工作区控制台';

  @override
  String get homeConsoleActivityTitle => '动态';

  @override
  String get homeConsoleActivityDescription => '已保存内容、话题、任务和搜索。';

  @override
  String get homeConsoleSavedMessages => '已保存消息';

  @override
  String get homeConsoleSavedMessagesDescription => '查看收藏的更新和引用。';

  @override
  String get homeConsoleThreads => '话题';

  @override
  String get homeConsoleThreadsDescription => '查看工作区内的活跃话题。';

  @override
  String get homeConsoleTasks => '任务';

  @override
  String get homeConsoleTasksDescription => '查看任务队列和执行状态。';

  @override
  String get homeConsoleSearch => '搜索';

  @override
  String get homeConsoleSearchDescription => '搜索频道、消息和工作区历史。';

  @override
  String get homeConsoleOperationsTitle => '运维';

  @override
  String get homeConsoleOperationsDescription => '成员、基础设施、账单和设置。';

  @override
  String get homeConsoleMembers => '成员';

  @override
  String get homeConsoleMembersDescription => '管理工作区角色和邀请。';

  @override
  String get homeConsoleAgentControl => '智能体管理';

  @override
  String get homeConsoleAgentControlDescription => '查看智能体活动和分配情况。';

  @override
  String get homeConsoleMachines => '机器';

  @override
  String get homeConsoleMachinesDescription => '查看工作区运行时容量和主机。';

  @override
  String get homeConsoleBilling => '账单';

  @override
  String get homeConsoleBillingDescription => '查看套餐和账单管理。';

  @override
  String get homeConsoleWorkspaceSettings => '工作区设置';

  @override
  String get homeConsoleWorkspaceSettingsDescription => '配置工作区级别的默认值和访问权限。';

  @override
  String get homeCardAgents => '智能体';

  @override
  String get homeCardAgentsSubtitle => '工作区中的智能体';

  @override
  String homeCardAgentsOnline(int count) {
    return '$count 在线';
  }

  @override
  String homeCardAgentsError(int count) {
    return '$count 错误';
  }

  @override
  String homeCardAgentsStopped(int count) {
    return '$count 已停止';
  }

  @override
  String get homeCardAgentsEmpty => '所有智能体离线';

  @override
  String get homeCardChannels => '频道';

  @override
  String get homeCardChannelsSubtitle => '活跃频道';

  @override
  String homeCardChannelsUnread(int count) {
    return '$count 未读';
  }

  @override
  String get homeCardTasks => '任务';

  @override
  String get homeCardTasksSubtitle => '全部任务';

  @override
  String get homeCardTasksEmpty => '暂无活跃任务';

  @override
  String homeCardTasksOverflow(int count) {
    return '还有 $count 项';
  }

  @override
  String get homeCardTasksInProgress => '进行中';

  @override
  String get homeCardTasksTodo => '待办';

  @override
  String homeCardTasksDurationMinutes(int count) {
    return '$count分钟';
  }

  @override
  String homeCardTasksDurationHours(int hours, int minutes) {
    return '$hours小时$minutes分钟';
  }

  @override
  String homeCardTasksDurationHoursOnly(int count) {
    return '$count小时';
  }

  @override
  String get homeCardThreads => '话题';

  @override
  String get homeCardViewAll => '查看全部';

  @override
  String get homeCardThreadsFilterUnread => '未读';

  @override
  String get homeCardThreadsFilterRead => '已读';

  @override
  String get homeCardThreadsFilterAll => '全部';

  @override
  String homeCardThreadsReplies(int count) {
    return '$count 条回复';
  }

  @override
  String homeCardThreadsNew(int count) {
    return '$count 条新消息';
  }

  @override
  String get homeCardThreadsEmpty => '暂无话题';

  @override
  String get homeCardAgentActivityOnline => '在线';

  @override
  String get homeCardAgentActivityThinking => '思考中';

  @override
  String get homeCardAgentActivityWorking => '工作中';

  @override
  String get homeCardAgentActivityError => '错误';

  @override
  String get homeCardAgentActivityOffline => '离线';

  @override
  String get homeCardTimeAgoNow => '刚刚';

  @override
  String homeCardTimeAgoMinutes(int count) {
    return '$count分钟前';
  }

  @override
  String homeCardTimeAgoHours(int count) {
    return '$count小时前';
  }

  @override
  String homeCardTimeAgoDays(int count) {
    return '$count天前';
  }

  @override
  String get homeCardUnread => '未读';

  @override
  String get homeCardUnreadEmpty => '全部已读';

  @override
  String homeCardUnreadOverflow(int count) {
    return '还有 $count 项';
  }

  @override
  String homeCardUnreadBadge(int count) {
    return '$count';
  }

  @override
  String get homeCardUnreadMarkAllRead => '全部标为已读';

  @override
  String get homeSectionPinned => '已置顶';

  @override
  String get homeSectionChannels => '频道';

  @override
  String get homeSectionDirectMessages => '私信';

  @override
  String get homeSectionPinnedAgents => '已置顶智能体';

  @override
  String get homeSectionAgents => '智能体';

  @override
  String get homeChannelsEmpty => '暂无频道。';

  @override
  String get homeDirectMessagesEmpty => '暂无私信。';

  @override
  String get homeCreateChannelTooltip => '创建频道';

  @override
  String get homeNewMessageTooltip => '新消息';

  @override
  String homeHiddenConversationsCount(int count) {
    return '隐藏的对话（$count）';
  }

  @override
  String get homeHiddenConversationsTitle => '隐藏的对话';

  @override
  String get homeUnhide => '取消隐藏';

  @override
  String get homePin => '置顶';

  @override
  String get homeUnpin => '取消置顶';

  @override
  String get homeNoServerMessage => '选择一个服务器以开始。';

  @override
  String get homeSelectWorkspace => '选择工作区';

  @override
  String get homeLoadFailedFallback => '无法加载对话列表。';

  @override
  String get homeRetry => '重试';

  @override
  String get channelsTabTitle => '频道';

  @override
  String get channelsTabPlaceholder => '频道列表即将上线。';

  @override
  String get channelsTabSearchHint => '搜索频道';

  @override
  String get channelsTabEmpty => '暂无频道。';

  @override
  String get dmsTabTitle => '消息';

  @override
  String get dmsTabHeadline => '私信';

  @override
  String get dmsTabPlaceholder => '私信列表即将上线。';

  @override
  String get dmsTabSearchHint => '搜索消息';

  @override
  String get dmsTabEmpty => '暂无私信。';

  @override
  String get settingsTooltip => '设置';

  @override
  String get homeChannelCreated => '频道已创建。';

  @override
  String get homeChannelCreateFailed => '创建频道失败。';

  @override
  String get homeChannelUpdated => '频道已更新。';

  @override
  String get homeChannelUpdateFailed => '更新频道失败。';

  @override
  String get homeDeleteChannelTitle => '删除频道';

  @override
  String homeDeleteChannelMessage(String name) {
    return '删除 $name？此操作无法撤销。';
  }

  @override
  String get homeDeleteChannelConfirm => '删除';

  @override
  String get homeChannelDeleted => '频道已删除。';

  @override
  String get homeChannelDeleteFailed => '删除频道失败。';

  @override
  String get homeLeaveChannelTitle => '离开频道';

  @override
  String homeLeaveChannelMessage(String name) {
    return '离开 $name？';
  }

  @override
  String get homeLeaveChannelConfirm => '离开';

  @override
  String get homeChannelLeft => '已离开频道。';

  @override
  String get homeChannelLeaveFailed => '离开频道失败。';

  @override
  String get baseUrlSettingsTitle => '服务器配置';

  @override
  String get baseUrlSettingsSubtitle => '配置自定义 API 和 WebSocket 端点。';

  @override
  String get baseUrlApiLabel => 'API 地址';

  @override
  String get baseUrlApiHint => 'https://api.example.com';

  @override
  String get baseUrlRealtimeLabel => '实时连接地址';

  @override
  String get baseUrlRealtimeHint => 'wss://realtime.example.com';

  @override
  String get baseUrlSave => '保存';

  @override
  String get baseUrlRestoreDefaults => '恢复默认';

  @override
  String get baseUrlTestConnection => '测试连接';

  @override
  String get baseUrlTesting => '测试中……';

  @override
  String get baseUrlSaved => '设置已保存。请重启应用以生效。';

  @override
  String get baseUrlRestored => '已恢复默认。请重启应用以生效。';

  @override
  String get baseUrlApiInvalidError => '请输入有效的 http:// 或 https:// 地址。';

  @override
  String get baseUrlRealtimeInvalidError =>
      '请输入有效的 ws://、wss://、http:// 或 https:// 地址。';

  @override
  String get baseUrlResultReachable => '可达';

  @override
  String get baseUrlResultUnauthorized => '可达（未授权）';

  @override
  String get baseUrlResultTimeout => '超时';

  @override
  String get baseUrlResultInvalid => '无效地址';

  @override
  String get baseUrlEmptyDefault => '使用编译时默认值';

  @override
  String get baseUrlRestartRequired => '需重启应用以应用更改。';

  @override
  String get baseUrlSettingsSettingsTile => '服务器';

  @override
  String get baseUrlSettingsSettingsTileSubtitle => '自定义 API 和 WebSocket 端点。';

  @override
  String get attachmentOpenInBrowser => '在浏览器中打开';

  @override
  String get attachmentUnableToLoadImage => '无法加载图片';

  @override
  String get attachmentHtmlOpensInBrowser => 'HTML · 在浏览器中打开';
}
