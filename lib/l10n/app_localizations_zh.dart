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
  String get agentsNoMachineAssigned => '未分配机器';

  @override
  String get releaseNotesTitle => '版本说明';

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
  String get homeCardTasks => '任务';

  @override
  String get homeCardTasksSubtitle => '全部任务';

  @override
  String get homeCardTasksEmpty => '暂无活跃任务';

  @override
  String get homeCardTasksUnavailable => '任务加载失败';

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
  String get homeCardViewAll => '查看全部';

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

  @override
  String get refreshFailedSnackbar => '刷新失败，显示缓存数据。';

  @override
  String get refreshFailedRetry => '重试';

  @override
  String get workspaceSettingsUnavailableTitle => '工作区设置不可用';

  @override
  String get workspaceSettingsUnavailableMessage => '目前无法加载工作区设置。';

  @override
  String get workspaceSettingsNotFound => '未找到工作区。';

  @override
  String get workspaceSettingsRoleLabel => '角色';

  @override
  String get workspaceSettingsRoleUnknown => '未知';

  @override
  String get workspaceSettingsCreatedLabel => '创建时间';

  @override
  String get workspaceSettingsManageSection => '管理';

  @override
  String get workspaceSettingsActionsSection => '操作';

  @override
  String get workspaceSettingsRenameAction => '重命名工作区';

  @override
  String get workspaceSettingsDeleteAction => '删除工作区';

  @override
  String get workspaceSettingsLeaveAction => '退出工作区';

  @override
  String get workspaceSettingsRenamedSnackbar => '工作区已重命名。';

  @override
  String get workspaceSettingsRenameFailed => '重命名工作区失败。';

  @override
  String get workspaceSettingsDeleteDialogTitle => '删除工作区？';

  @override
  String workspaceSettingsDeleteDialogMessage(String name) {
    return '删除 $name？此操作将永久移除工作区及其所有数据。';
  }

  @override
  String get workspaceSettingsDeleteConfirmLabel => '删除';

  @override
  String get workspaceSettingsDeleteFailed => '删除工作区失败。';

  @override
  String get workspaceSettingsLeaveDialogTitle => '退出工作区？';

  @override
  String workspaceSettingsLeaveDialogMessage(String name) {
    return '退出 $name？之后可通过新邀请重新加入。';
  }

  @override
  String get workspaceSettingsLeaveConfirmLabel => '退出';

  @override
  String get workspaceSettingsLeaveFailed => '退出工作区失败。';

  @override
  String get previewDeleted => '消息已删除';

  @override
  String get previewSending => '正在发送...';

  @override
  String get previewFailed => '未发送，点击重试';

  @override
  String get previewSystem => '系统消息';

  @override
  String get previewLink => '链接';

  @override
  String get previewVoice => '语音消息';

  @override
  String get previewImage => '图片';

  @override
  String get previewVideo => '视频';

  @override
  String get previewFallback => '新消息';

  @override
  String previewAttachment(String name) {
    return '附件: $name';
  }

  @override
  String get agentStatusThinking => '思考中';

  @override
  String get agentStatusWorking => '工作中';

  @override
  String get agentStatusError => '错误';

  @override
  String get agentStatusOnline => '在线';

  @override
  String get agentStatusOffline => '离线';

  @override
  String get agentStatusStopped => '已停止';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAccountSection => '账户';

  @override
  String get settingsWorkspaceSection => '工作区';

  @override
  String get settingsNotificationsSection => '通知';

  @override
  String get settingsAppearanceSection => '外观';

  @override
  String get settingsLanguageSection => '语言';

  @override
  String get settingsSecuritySection => '安全';

  @override
  String get settingsMoreSection => '更多';

  @override
  String get settingsDangerZoneSection => '危险区域';

  @override
  String get settingsMyProfileTitle => '我的资料';

  @override
  String get settingsMyProfileSubtitle => '查看您的当前账户详情。';

  @override
  String get settingsMembersTitle => '成员';

  @override
  String get settingsMembersSubtitle => '查看和管理工作区成员。';

  @override
  String get settingsNotificationSettingsTitle => '通知设置';

  @override
  String get settingsThemeTitle => '主题';

  @override
  String get settingsTranslationTitle => '翻译';

  @override
  String get settingsTranslationSubtitle => '首选语言和翻译模式。';

  @override
  String get settingsBiometricLockTitle => '生物识别锁定';

  @override
  String get settingsBiometricLockEnabled => '已启用 - 不活动后使用生物识别解锁';

  @override
  String get settingsBiometricLockDisabled => '已禁用 - 无生物识别锁定';

  @override
  String get settingsBillingTitle => '账单';

  @override
  String get settingsBillingSubtitle => '查看您的当前订阅摘要。';

  @override
  String get settingsReleaseNotesTitle => '发布说明';

  @override
  String get settingsReleaseNotesSubtitle => '查看最新的产品更新。';

  @override
  String get settingsDiagnosticsTitle => '诊断';

  @override
  String get settingsDiagnosticsSubtitle => '查看和导出诊断日志。';

  @override
  String get settingsLogOutTitle => '退出登录';

  @override
  String get settingsLogOutSubtitle => '退出此设备。';

  @override
  String get settingsLogOutDialogTitle => '确认退出？';

  @override
  String get settingsLogOutDialogContent => '您将退出此设备的登录。';

  @override
  String get settingsLogOutDialogCancel => '取消';

  @override
  String get settingsLogOutDialogConfirm => '退出';

  @override
  String get settingsSignedInFallback => '已登录';

  @override
  String get settingsAccountUnavailable => '账户信息不可用';

  @override
  String get settingsNotificationGranted => '已授权';

  @override
  String get settingsNotificationDenied => '已拒绝';

  @override
  String get settingsNotificationProvisional => '临时授权';

  @override
  String get settingsNotificationNotRequested => '未请求';

  @override
  String get notificationSettingsTitle => '通知设置';

  @override
  String get notificationSettingsPermissionSection => '权限';

  @override
  String get notificationSettingsPushNotifications => '推送通知';

  @override
  String get notificationSettingsFilterSection => '通知过滤';

  @override
  String get notificationSettingsDiagnosticsSection => '诊断';

  @override
  String get notificationSettingsDeviceToken => '设备令牌';

  @override
  String get notificationSettingsPlatform => '平台';

  @override
  String get notificationSettingsLastRegistration => '最近注册';

  @override
  String get notificationSettingsPermissionStatus => '权限状态';

  @override
  String get notificationSettingsRecentEvents => '最近事件';

  @override
  String get notificationSettingsNoEvents => '暂无最近通知事件。';

  @override
  String get notificationSettingsNotAvailable => '不可用';

  @override
  String get notificationSettingsNotRegistered => '尚未注册';

  @override
  String get notificationSettingsUpdateFailed => '无法更新通知设置。';

  @override
  String get notificationSettingsRefreshRegistration => '刷新设备注册';

  @override
  String get notificationSettingsRetryAccess => '重试通知访问';

  @override
  String get notificationSettingsEnable => '启用推送通知';

  @override
  String get notificationSettingsPermissionGranted => '权限已授予';

  @override
  String get notificationSettingsPermissionDenied => '权限已拒绝';

  @override
  String get notificationSettingsPermissionProvisional => '权限为临时授予';

  @override
  String get notificationSettingsPermissionUnknown => '权限尚未请求';

  @override
  String notificationSettingsDeviceRegistered(String date) {
    return '设备已注册于 $date。';
  }

  @override
  String get notificationSettingsDeviceNotRegistered => '设备注册暂不可用。';

  @override
  String get notificationSettingsResultGranted => '通知访问已授权，设备注册已刷新。';

  @override
  String get notificationSettingsResultProvisional => '通知访问为临时授权，设备注册已刷新。';

  @override
  String get notificationSettingsResultDenied => '通知访问被拒绝。';

  @override
  String get notificationSettingsResultUnknown => '此设备上的通知状态仍不可用。';

  @override
  String get searchHintText => '搜索消息、频道或联系人...';

  @override
  String get searchIdleText => '输入以搜索消息、频道或联系人。';

  @override
  String get searchNoResults => '未找到结果。';

  @override
  String get searchRetry => '重试';

  @override
  String get searchFailedFallback => '搜索失败。';

  @override
  String get searchSectionChannels => '频道';

  @override
  String get searchSectionContacts => '联系人';

  @override
  String get searchSectionMessages => '消息';

  @override
  String get searchViewAll => '查看全部';

  @override
  String get searchLoadMore => '加载更多';

  @override
  String get searchFilterSender => '发送者';

  @override
  String get searchFilterChannel => '频道';

  @override
  String get searchFilterClear => '清除';

  @override
  String get searchFilterNewest => '最新';

  @override
  String get searchFilterOldest => '最早';

  @override
  String get searchFilterBySenderTitle => '按发送者筛选';

  @override
  String get searchFilterBySenderHint => '输入发送者名称…';

  @override
  String get searchFilterByChannelTitle => '按频道筛选';

  @override
  String get searchFilterByChannelHint => '输入频道名称…';

  @override
  String get searchFilterCancel => '取消';

  @override
  String get searchFilterApply => '应用';

  @override
  String get searchFilterDateAny => '不限时间';

  @override
  String get searchFilterDateToday => '今天';

  @override
  String get searchFilterDateWeek => '最近一周';

  @override
  String get searchFilterDateMonth => '最近一月';

  @override
  String get searchCouldNotOpenConversation => '无法打开会话。';

  @override
  String searchFilterFromPrefix(String name) {
    return '来自: $name';
  }

  @override
  String searchFilterInPrefix(String name) {
    return '在: $name';
  }

  @override
  String get searchRecentTitle => '最近搜索';

  @override
  String get searchRecentClear => '清除';

  @override
  String get machinesPageTitle => '机器';

  @override
  String get machinesAddButton => '添加机器';

  @override
  String get machinesLoadFailed => '加载机器列表失败。';

  @override
  String get machinesRegisterTitle => '注册机器';

  @override
  String get machinesRegisterAction => '注册';

  @override
  String get machinesRegisterHelper => '创建机器并显示一次其 API 密钥。';

  @override
  String get machinesRegisteredTitle => '机器已注册';

  @override
  String get machinesRegisterFailed => '注册机器失败。';

  @override
  String get machinesRenameTitle => '重命名机器';

  @override
  String get machinesRenameSaveAction => '保存';

  @override
  String get machinesRenameHelper => '更新在工作区中显示的机器名称。';

  @override
  String get machinesRenamedSnackbar => '机器已重命名。';

  @override
  String get machinesRenameFailed => '重命名机器失败。';

  @override
  String get machinesRotatedApiKeyTitle => 'API 密钥已轮换';

  @override
  String get machinesRotateApiKeyFailed => '轮换机器 API 密钥失败。';

  @override
  String get machinesDeleteTitle => '删除机器？';

  @override
  String get machinesDeleteCancel => '取消';

  @override
  String get machinesDeleteConfirm => '删除';

  @override
  String get machinesDeletedSnackbar => '机器已删除。';

  @override
  String get machinesDeleteFailed => '删除机器失败。';

  @override
  String get machinesApiKeyRevealedNote => '此密钥仅在创建或轮换时显示一次。';

  @override
  String get machinesApiKeyCopied => 'API 密钥已复制。';

  @override
  String get machinesCopyButton => '复制';

  @override
  String get machinesDoneButton => '完成';

  @override
  String get machinesRetryButton => '重试';

  @override
  String get machinesLatestDaemon => '最新守护进程';

  @override
  String get machinesEmptyTitle => '暂无已注册的机器。';

  @override
  String get machinesEmptyDescription => '注册机器以将运行时和管理操作附加到此服务器。';

  @override
  String get machinesRegisterButton => '注册机器';

  @override
  String get machinesMenuRename => '重命名';

  @override
  String get machinesMenuRotateApiKey => '轮换 API 密钥';

  @override
  String get machinesMenuDelete => '删除';

  @override
  String get machinesMetaHost => '主机';

  @override
  String get machinesMetaOs => '操作系统';

  @override
  String get machinesMetaDaemon => '守护进程';

  @override
  String get machinesStatusOnline => '在线';

  @override
  String get machinesStatusOffline => '离线';

  @override
  String get machinesStatusError => '错误';

  @override
  String get machinesNameLabel => '机器名称';

  @override
  String get machinesNameDialogCancel => '取消';

  @override
  String machinesDeleteMessage(String name) {
    return '删除 $name？此操作将从服务器列表中移除该机器。';
  }

  @override
  String machinesCopyApiKeyMessage(String name) {
    return '请立即复制 $name 的 API 密钥。';
  }

  @override
  String machinesSummaryCount(int count) {
    return '$count 台机器';
  }

  @override
  String machinesSummaryOnline(int count) {
    return '$count 在线';
  }

  @override
  String machinesApiKeyPrefix(String prefix) {
    return '密钥 $prefix...';
  }

  @override
  String get machinesMenuWorkspaces => '工作区';

  @override
  String get workspacesPageTitle => '工作区';

  @override
  String get workspacesEmpty => '此机器上没有工作区。';

  @override
  String get workspacesLoadFailed => '加载工作区失败。';

  @override
  String get workspacesRetryButton => '重试';

  @override
  String get workspacesDeleteTitle => '删除工作区？';

  @override
  String workspacesDeleteMessage(String name) {
    return '删除工作区 \"$name\"？此操作无法撤销。';
  }

  @override
  String get workspacesDeleteCancel => '取消';

  @override
  String get workspacesDeleteConfirm => '删除';

  @override
  String get workspacesDeletedSnackbar => '工作区已删除。';

  @override
  String get workspacesDeleteFailed => '删除工作区失败。';

  @override
  String get workspacesMetaPath => '路径';

  @override
  String get workspacesMetaAgent => '代理';

  @override
  String get workspacesStatusActive => '活跃';

  @override
  String get workspacesStatusInactive => '非活跃';

  @override
  String get tasksLoadFailed => '加载任务失败。';

  @override
  String get tasksEmptyAll => '暂无任务。';

  @override
  String get tasksNoChannelsAvailable => '暂无可用频道。';

  @override
  String get tasksCreatedSnackbar => '任务已创建。';

  @override
  String get tasksCreateFailed => '创建任务失败。';

  @override
  String get tasksUpdateFailed => '更新任务失败。';

  @override
  String get tasksRetryAction => '重试';

  @override
  String get tasksDeleteTitle => '删除任务？';

  @override
  String tasksDeleteMessage(String title) {
    return '删除「$title」？此操作无法撤销。';
  }

  @override
  String get tasksDeleteCancel => '取消';

  @override
  String get tasksDeleteConfirm => '删除';

  @override
  String get tasksDeletedSnackbar => '任务已删除。';

  @override
  String get tasksDeleteFailed => '删除任务失败。';

  @override
  String get tasksClaimFailed => '认领任务失败。';

  @override
  String get tasksUnclaimFailed => '取消认领任务失败。';

  @override
  String get tasksHeaderTitle => '任务';

  @override
  String get tasksNewButton => '新建';

  @override
  String get tasksSummaryTodo => '待办';

  @override
  String get tasksSummaryInProgress => '进行中';

  @override
  String get tasksSummaryReview => '审核';

  @override
  String get tasksSummaryDone => '已完成';

  @override
  String get tasksSummaryClosed => '已关闭';

  @override
  String get tasksEmptyChannel => '此频道暂无任务。';

  @override
  String get tasksFilterAll => '全部';

  @override
  String get tasksSectionTodo => '待办';

  @override
  String get tasksSectionInProgress => '进行中';

  @override
  String get tasksSectionInReview => '审核中';

  @override
  String get tasksSectionDone => '已完成';

  @override
  String get tasksSectionClosed => '已关闭';

  @override
  String get tasksActionsTooltip => '任务操作';

  @override
  String get tasksSwipeDone => '完成';

  @override
  String get tasksActionMarkDone => '标记完成';

  @override
  String get tasksActionClose => '关闭任务';

  @override
  String get tasksActionStart => '开始';

  @override
  String get tasksActionMoveToReview => '移至审核';

  @override
  String get tasksActionReopen => '重新打开';

  @override
  String get tasksActionRevertInProgress => '恢复为进行中';

  @override
  String get tasksActionRevertTodo => '恢复为待办';

  @override
  String get tasksActionClaim => '认领';

  @override
  String get tasksActionUnclaim => '取消认领';

  @override
  String get tasksActionDelete => '删除';

  @override
  String get tasksRetryButton => '重试';

  @override
  String get tasksCreateTitle => '创建任务';

  @override
  String get tasksCreateChannelLabel => '频道';

  @override
  String get tasksCreateTitleLabel => '标题';

  @override
  String get tasksCreateCancel => '取消';

  @override
  String get tasksCreateConfirm => '创建';

  @override
  String get tasksAccessibilityTodo => '待办';

  @override
  String get tasksAccessibilityInProgress => '进行中';

  @override
  String get tasksAccessibilityInReview => '审核中';

  @override
  String get tasksAccessibilityDone => '已完成';

  @override
  String get tasksAccessibilityClosed => '已取消';

  @override
  String get screenshotAnnotateNoCapture => '未捕获截图';

  @override
  String get screenshotAnnotateDiscardTooltip => '放弃';

  @override
  String get screenshotAnnotateTitle => '标注截图';

  @override
  String get screenshotAnnotateSaveTooltip => '保存到设备';

  @override
  String get screenshotAnnotateShareTooltip => '分享';

  @override
  String get screenshotAnnotateAddTextTitle => '添加文字';

  @override
  String get screenshotAnnotateTextHint => '输入文字...';

  @override
  String get screenshotAnnotateCancel => '取消';

  @override
  String get screenshotAnnotateAddButton => '添加';

  @override
  String get screenshotAnnotateExportFailed => '导出截图失败';

  @override
  String screenshotAnnotateExportError(String error) {
    return '导出失败：$error';
  }

  @override
  String screenshotAnnotateSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get screenshotAnnotateShareSubject => '截图';

  @override
  String get dateSeparatorToday => '今天';

  @override
  String get dateSeparatorYesterday => '昨天';

  @override
  String get conversationComposerHint => '写消息';

  @override
  String get conversationComposerAttachPhotoVideo => '照片和视频';

  @override
  String get conversationComposerAttachCamera => '相机';

  @override
  String get conversationComposerAttachFile => '文件';

  @override
  String get conversationComposerSendFailedFallback => '发送消息失败。';

  @override
  String get conversationComposerAttachTooltip => '附加文件';

  @override
  String get conversationComposerFormattingTooltip => '格式设置';

  @override
  String get conversationComposerEmojiTooltip => '表情';

  @override
  String get conversationComposerCameraUnavailable => '相机不可用。请检查权限。';

  @override
  String get conversationContextEditMessage => '编辑消息';

  @override
  String get conversationContextReply => '回复';

  @override
  String get conversationContextSelect => '选择';

  @override
  String get conversationContextReact => '回应';

  @override
  String get conversationContextTranslate => '翻译';

  @override
  String get conversationContextCopyText => '复制文本';

  @override
  String get conversationContextForward => '转发';

  @override
  String get conversationContextSaveMessage => '保存消息';

  @override
  String get conversationContextUnsaveMessage => '取消保存消息';

  @override
  String get conversationContextPinMessage => '置顶消息';

  @override
  String get conversationContextUnpinMessage => '取消置顶消息';

  @override
  String get conversationContextReplyInThread => '在线程中回复';

  @override
  String get conversationContextCreateTask => '创建任务';

  @override
  String get conversationContextDeleteMessage => '删除消息';

  @override
  String get conversationSelectionCancel => '取消';

  @override
  String get conversationSelectionSave => '保存';

  @override
  String get conversationSelectionExportAsImage => '导出为图片';

  @override
  String get conversationSelectionDelete => '删除';

  @override
  String conversationSelectionSelected(int count) {
    return '已选择 $count 项';
  }

  @override
  String conversationSelectionBatchSucceeded(int count, String action) {
    return '已$action $count 条。';
  }

  @override
  String conversationSelectionBatchFailed(String action, int count) {
    return '$action $count 条消息失败。';
  }

  @override
  String conversationSelectionBatchPartial(
      int succeeded, String action, int failed) {
    return '已$action $succeeded 条，$failed 条失败。';
  }

  @override
  String get conversationSelectionActionSaveVerb => '保存';

  @override
  String get conversationSelectionActionSaved => '保存';

  @override
  String get conversationSelectionActionDeleteVerb => '删除';

  @override
  String get conversationSelectionActionDeleted => '删除';

  @override
  String get conversationEditDialogTitle => '编辑消息';

  @override
  String get conversationEditDialogCancel => '取消';

  @override
  String get conversationEditDialogSave => '保存';

  @override
  String get conversationEditSuccess => '消息已编辑。';

  @override
  String get conversationEditFailedFallback => '编辑消息失败。';

  @override
  String get conversationMessageDeletedPlaceholder => '[消息已删除]';

  @override
  String get conversationReactionFailedFallback => '添加回应失败。';

  @override
  String get conversationReactWithEmojiTitle => '用表情回应';

  @override
  String conversationReactWithEmojiSemantics(String emoji) {
    return '用 $emoji 回应';
  }

  @override
  String get conversationReactionUpdateFailedFallback => '更新回应失败。';

  @override
  String get conversationDeleteDialogTitle => '删除消息？';

  @override
  String get conversationDeleteDialogContent => '此消息将被永久删除。';

  @override
  String get conversationDeleteDialogCancel => '取消';

  @override
  String get conversationDeleteDialogConfirm => '删除';

  @override
  String get conversationDeleteSuccess => '消息已删除。';

  @override
  String get conversationDeleteFailedFallback => '删除消息失败。';

  @override
  String get conversationOpenLinkTitle => '打开链接';

  @override
  String conversationOpenLinkContent(String url) {
    return '打开 $url？';
  }

  @override
  String get conversationOpenLinkCancel => '取消';

  @override
  String get conversationOpenLinkConfirm => '打开';

  @override
  String get conversationMessageActionsSemantics => '消息操作';

  @override
  String get conversationShowMessageMenuSemantics => '显示消息菜单';

  @override
  String get conversationReplySemantics => '回复';

  @override
  String get channelStopAllAgents => '停止所有 Agent';

  @override
  String get channelResumeAllAgents => '恢复所有 Agent';

  @override
  String get channelStopAllAgentsTitle => '停止所有 Agent';

  @override
  String get channelStopAllAgentsMessage => '停止此频道中的所有 Agent？停止后它们将不会响应，直到恢复。';

  @override
  String get channelStopAllAgentsConfirm => '全部停止';

  @override
  String get channelStopAllAgentsSuccess => '所有 Agent 已停止。';

  @override
  String get channelStopAllAgentsFailed => '停止 Agent 失败。';

  @override
  String get channelResumeAllAgentsSuccess => '所有 Agent 已恢复。';

  @override
  String get channelResumeAllAgentsFailed => '恢复 Agent 失败。';

  @override
  String get cancel => '取消';

  @override
  String get errorNetwork => '网络连接失败，请检查网络后重试。';

  @override
  String get errorTimeout => '请求超时，请稍后重试。';

  @override
  String get errorUnauthorized => '登录已过期，请重新登录。';

  @override
  String get errorForbidden => '没有权限执行此操作。';

  @override
  String get errorNotFound => '请求的资源不存在。';

  @override
  String get errorConflict => '发生冲突，请刷新后重试。';

  @override
  String get errorValidation => '输入无效，请检查后重试。';

  @override
  String get errorRateLimit => '请求过于频繁，请稍后再试。';

  @override
  String get errorServer => '服务器错误，请稍后重试。';

  @override
  String get errorCancelled => '请求已取消。';

  @override
  String get errorUnknown => '操作失败，请重试。';

  @override
  String get pendingNewMessages => '新消息';

  @override
  String get pendingSending => '发送中……';

  @override
  String get pendingQueued => '已排队 — 等待网络连接';

  @override
  String get pendingSent => '已发送';

  @override
  String get pendingFailedToSend => '发送失败';

  @override
  String get pendingRetry => '重试';

  @override
  String get pendingDismiss => '取消';

  @override
  String get pendingEarlierHistoryLimited => '更早的历史记录不可用。';

  @override
  String get composerSendTooltip => '发送';

  @override
  String get composerVoiceMessageTooltip => '语音消息';

  @override
  String get composerFileTooLarge => '文件过大，最大支持 50 MB';

  @override
  String get messageSenderYou => '你';

  @override
  String get channelActionMoveUp => '上移';

  @override
  String get channelActionMoveDown => '下移';

  @override
  String get channelActionPin => '置顶频道';

  @override
  String get channelActionUnpin => '取消置顶';

  @override
  String get channelActionMarkUnread => '标记为未读';

  @override
  String get channelActionEdit => '编辑频道';

  @override
  String get channelActionLeave => '离开频道';

  @override
  String get channelActionDelete => '删除频道';

  @override
  String get onboardingWelcomeTitle => '欢迎使用 Slock';

  @override
  String get onboardingBack => '返回';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingFinish => '完成';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingSetupTitle => '设置你的工作区';

  @override
  String get onboardingSetupBody => 'Slock 已准备就绪。花一分钟配置通知和个人资料，然后开始使用。';

  @override
  String get onboardingNotificationsTitle => '保持同步';

  @override
  String get onboardingNotificationsBody => '启用通知，让提及、回复和任务及时到达你。';

  @override
  String get onboardingNotificationsButton => '启用通知';

  @override
  String get onboardingProfileTitle => '完善你的个人资料';

  @override
  String get onboardingProfileBody => '添加显示名称、简介或头像，让队友更容易认出你。';

  @override
  String get onboardingProfileButton => '编辑个人资料';
}
