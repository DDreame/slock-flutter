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
  String get releaseNotesTitle => '版本说明';

  @override
  String get homeConsoleMembers => '成员';

  @override
  String get homeConsoleBilling => '账单';

  @override
  String get homeConsoleWorkspaceSettings => '工作区设置';

  @override
  String get homeCardAgents => '智能体';

  @override
  String get homeCardAgentsSubtitle => '工作区中的智能体';

  @override
  String get homeCardAgentsEmpty => '所有智能体离线';

  @override
  String get homeCardTasks => '任务';

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
  String get homeCardViewAll => '查看全部';

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
  String get channelsTabSearchHint => '搜索频道';

  @override
  String get channelsTabEmpty => '暂无频道。';

  @override
  String get dmsTabTitle => '消息';

  @override
  String get dmsTabSearchHint => '搜索消息';

  @override
  String get dmsTabEmpty => '暂无私信。';

  @override
  String get settingsTooltip => '设置';

  @override
  String get homeChannelCreated => '频道已创建。';

  @override
  String get homeChannelUpdated => '频道已更新。';

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
  String get baseUrlSettingsTitle => '服务器配置';

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
  String get workspaceSettingsDeleteDialogTitle => '删除工作区？';

  @override
  String workspaceSettingsDeleteDialogMessage(String name) {
    return '删除 $name？此操作将永久移除工作区及其所有数据。';
  }

  @override
  String get workspaceSettingsDeleteConfirmLabel => '删除';

  @override
  String get workspaceSettingsLeaveDialogTitle => '退出工作区？';

  @override
  String workspaceSettingsLeaveDialogMessage(String name) {
    return '退出 $name？之后可通过新邀请重新加入。';
  }

  @override
  String get workspaceSettingsLeaveConfirmLabel => '退出';

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
  String get notificationSettingsDateRecently => '最近';

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
  String get machinesRenameTitle => '重命名机器';

  @override
  String get machinesRenameSaveAction => '保存';

  @override
  String get machinesRenameHelper => '更新在工作区中显示的机器名称。';

  @override
  String get machinesRenamedSnackbar => '机器已重命名。';

  @override
  String get machinesRotatedApiKeyTitle => 'API 密钥已轮换';

  @override
  String get machinesDeleteTitle => '删除机器？';

  @override
  String get machinesDeleteCancel => '取消';

  @override
  String get machinesDeleteConfirm => '删除';

  @override
  String get machinesDeletedSnackbar => '机器已删除。';

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
  String get workspacesMetaPath => '路径';

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
  String get conversationReactWithEmojiTitle => '用表情回应';

  @override
  String conversationReactWithEmojiSemantics(String emoji) {
    return '用 $emoji 回应';
  }

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
  String get channelsSortAlphabetical => '按字母排序';

  @override
  String get channelsSortRecent => '按最近活动排序';

  @override
  String get channelsMarkAllRead => '全部标记已读';

  @override
  String get channelsClearSearch => '清除搜索';

  @override
  String get channelsMarkedUnread => '已标记为未读';

  @override
  String get channelsCreateTitle => '新建频道';

  @override
  String get channelsCreateSectionName => '频道名称';

  @override
  String get channelsCreateNameHint => '频道名称';

  @override
  String get channelsCreateSectionDescription => '描述（可选）';

  @override
  String get channelsCreateDescriptionHint => '这个频道是关于什么的？';

  @override
  String get channelsCreateSectionVisibility => '可见性';

  @override
  String get channelsCreateSubmitting => '创建中...';

  @override
  String get channelsCreateSubmit => '创建频道';

  @override
  String get channelsCreateNoServer => '未选择活动服务器。';

  @override
  String get channelsCreateVisibilityPublic => '公开';

  @override
  String get channelsCreateVisibilityPublicSub => '所有人可见';

  @override
  String get channelsCreateVisibilityPrivate => '私密';

  @override
  String get channelsCreateVisibilityPrivateSub => '仅限邀请';

  @override
  String get channelsMembersTitle => '频道成员';

  @override
  String get channelsMembersRetry => '重试';

  @override
  String get channelsMembersEmpty => '此频道暂无成员。';

  @override
  String get channelsMembersTypeAgent => 'AI 代理';

  @override
  String get channelsMembersTypeHuman => '用户';

  @override
  String get channelsMembersMessageTooltip => '发送消息';

  @override
  String get channelsMembersRemoveTitle => '移除成员？';

  @override
  String channelsMembersRemoveMessage(String name) {
    return '确定要将 $name 从此频道移除吗？';
  }

  @override
  String get channelsMembersRemoveCancel => '取消';

  @override
  String get channelsMembersRemoveConfirm => '移除';

  @override
  String get channelsAddMemberTitle => '添加成员';

  @override
  String get channelsAddMemberTabHumans => '用户';

  @override
  String get channelsAddMemberTabAgents => 'AI 代理';

  @override
  String get channelsAddMemberClose => '关闭';

  @override
  String get channelsAddMemberNoHumans => '没有更多用户可添加。';

  @override
  String get channelsAddMemberNoAgents => '没有更多代理可添加。';

  @override
  String get channelsDialogCreateTitle => '创建频道';

  @override
  String get channelsDialogCreateNameLabel => '频道名称';

  @override
  String get channelsDialogCreateCancel => '取消';

  @override
  String get channelsDialogCreateSubmitting => '创建中...';

  @override
  String get channelsDialogCreateSubmit => '创建';

  @override
  String get channelsDialogEditTitle => '编辑频道';

  @override
  String get channelsDialogEditNameLabel => '频道名称';

  @override
  String get channelsDialogEditCancel => '取消';

  @override
  String get channelsDialogEditSubmitting => '保存中...';

  @override
  String get channelsDialogEditSubmit => '保存';

  @override
  String get channelsDialogConfirmCancel => '取消';

  @override
  String get channelsDialogConfirmWorking => '处理中...';

  @override
  String get serversInviteTitle => '加入工作区';

  @override
  String get serversInviteJoining => '正在加入工作区...';

  @override
  String get serversInviteFailedFallback => '加入工作区失败。';

  @override
  String get serversInviteRetry => '重试';

  @override
  String get serversInviteGoHome => '返回首页';

  @override
  String get serversInviteDescription => '您已被邀请加入一个工作区。';

  @override
  String get serversInviteAccept => '加入工作区';

  @override
  String get serversInviteCancel => '取消';

  @override
  String serversInviteSuccessNamed(String name) {
    return '已加入 $name！';
  }

  @override
  String get serversInviteSuccessGeneric => '已加入工作区！';

  @override
  String get serversInviteContinue => '继续';

  @override
  String get serversDialogCreateTitle => '创建工作区';

  @override
  String get serversDialogCreateNameLabel => '工作区名称';

  @override
  String get serversDialogCreateCancel => '取消';

  @override
  String get serversDialogCreateSubmit => '创建';

  @override
  String get serversDialogRenameTitle => '重命名工作区';

  @override
  String get serversDialogRenameNameLabel => '工作区名称';

  @override
  String get serversDialogRenameCancel => '取消';

  @override
  String get serversDialogRenameSubmit => '保存';

  @override
  String get serversDialogJoinTitle => '加入工作区';

  @override
  String get serversDialogJoinLabel => '邀请码或链接';

  @override
  String get serversDialogJoinHint => 'https://slock.ai/invite/token-123';

  @override
  String get serversDialogJoinCancel => '取消';

  @override
  String get serversDialogJoinSubmit => '加入';

  @override
  String get serversDialogConfirmCancel => '取消';

  @override
  String get serversSwitcherTitle => '切换工作区';

  @override
  String get serversSwitcherCreating => '创建中...';

  @override
  String get serversSwitcherCreateAction => '创建工作区';

  @override
  String get serversSwitcherJoining => '加入中...';

  @override
  String get serversSwitcherJoinAction => '加入工作区';

  @override
  String get serversSwitcherEmpty => '暂无可用工作区。';

  @override
  String get serversSwitcherSettings => '工作区设置';

  @override
  String get serversSwitcherCreatedSnackbar => '工作区已创建。';

  @override
  String get serversSwitcherJoinedSnackbar => '已加入工作区。';

  @override
  String get serversSwitcherDeleteTitle => '删除工作区？';

  @override
  String serversSwitcherDeleteMessage(String name) {
    return '删除 $name？此操作将永久移除该工作区。';
  }

  @override
  String get serversSwitcherDeleteConfirm => '删除';

  @override
  String get serversSwitcherDeletedSnackbar => '工作区已删除。';

  @override
  String get serversSwitcherLeaveTitle => '离开工作区？';

  @override
  String serversSwitcherLeaveMessage(String name) {
    return '离开 $name？您稍后可通过新邀请重新加入。';
  }

  @override
  String get serversSwitcherLeaveConfirm => '离开';

  @override
  String get serversSwitcherLeftSnackbar => '已离开工作区。';

  @override
  String get serversSwitcherRenamedSnackbar => '工作区已重命名。';

  @override
  String get serversSwitcherRowRename => '重命名';

  @override
  String get serversSwitcherRowDelete => '删除工作区';

  @override
  String get serversSwitcherRowLeave => '离开工作区';

  @override
  String get serversSwitcherRetry => '重试';

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

  @override
  String get agentsEmptyTitle => '暂无智能体。';

  @override
  String get agentsSelectServerFirst => '请先选择一个服务器。';

  @override
  String get agentsCreated => '智能体已创建。';

  @override
  String get agentsUpdated => '智能体已更新。';

  @override
  String get agentsDeleted => '智能体已删除。';

  @override
  String get agentsResetSuccess => '智能体已重置。';

  @override
  String get agentsDeleteTitle => '删除智能体？';

  @override
  String agentsDeleteMessage(String name) {
    return '删除 $name？这将从工作区移除该智能体配置。';
  }

  @override
  String get agentsStopTitle => '停止智能体？';

  @override
  String agentsStopMessage(String name) {
    return '停止 $name？智能体将在完成当前操作后停止。';
  }

  @override
  String get agentsResetTitle => '重置会话？';

  @override
  String agentsResetMessage(String name) {
    return '重置 $name？这将清除智能体的对话历史。';
  }

  @override
  String agentsSummary(int active, int stopped) {
    return '$active 运行中 / $stopped 已停止';
  }

  @override
  String get agentsActionStart => '启动';

  @override
  String get agentsActionStop => '停止';

  @override
  String get agentsActionReset => '重置';

  @override
  String get agentsActionResetSession => '重置会话';

  @override
  String get agentsActionMessage => '发消息';

  @override
  String get agentsActionDelete => '删除';

  @override
  String get agentsActionCancel => '取消';

  @override
  String get agentsAppBarTitle => '智能体';

  @override
  String get agentsFailedToLoad => '加载智能体失败。';

  @override
  String get agentsNotFound => '未找到智能体。';

  @override
  String get agentsActivityLogTitle => '活动日志';

  @override
  String get agentsActivityLogEmpty => '暂无活动日志。';

  @override
  String get agentsConfigMachine => '机器';

  @override
  String get agentsConfigRuntime => '运行时';

  @override
  String get agentsConfigModel => '模型';

  @override
  String get agentsConfigReasoning => '推理';

  @override
  String get agentsEnvVarsTitle => '环境变量';

  @override
  String get agentsEnvVarsEmpty => '无环境变量';

  @override
  String get agentsRetry => '重试';

  @override
  String get agentsActivityOnline => '在线';

  @override
  String get agentsActivityThinking => '思考中…';

  @override
  String get agentsActivityWorking => '工作中…';

  @override
  String get agentsActivityError => '错误';

  @override
  String agentsActivityErrorDetail(String detail) {
    return '错误：$detail';
  }

  @override
  String get agentsActivityOffline => '离线';

  @override
  String get agentsFormEditTitle => '编辑智能体';

  @override
  String get agentsFormCreateTitle => '创建智能体';

  @override
  String get agentsFormNameRequired => '名称不能为空。';

  @override
  String get agentsFormMachineRequired => '请选择机器。';

  @override
  String get agentsFormRuntimeRequired => '请选择运行时。';

  @override
  String get agentsFormModelRequired => '请选择模型。';

  @override
  String get agentsFormNoMachines => '该服务器暂无可用机器。';

  @override
  String get agentsFormLabelMachine => '机器';

  @override
  String get agentsFormLabelName => '名称';

  @override
  String get agentsFormLabelDescription => '描述';

  @override
  String get agentsFormLabelRuntime => '运行时';

  @override
  String get agentsFormLabelModel => '模型';

  @override
  String get agentsFormLabelReasoningEffort => '推理强度';

  @override
  String get agentsFormSave => '保存';

  @override
  String get agentsFormCreate => '创建';

  @override
  String get agentsFormCancel => '取消';

  @override
  String get agentsFormRetry => '重试';

  @override
  String get agentsReasoningLow => '低';

  @override
  String get agentsReasoningMedium => '中';

  @override
  String get agentsReasoningHigh => '高';

  @override
  String get agentsReasoningExtraHigh => '极高';

  @override
  String get agentsFormConfiguredDefault => '使用配置默认值';

  @override
  String get profileEditTitle => '编辑资料';

  @override
  String get profileEditSave => '保存';

  @override
  String get profileEditSnackbarSaved => '资料已更新。';

  @override
  String get profileEditSnackbarAvatarSavedProfileFailed =>
      '头像已更新。资料保存失败——点击保存重试。';

  @override
  String get profileEditNewAvatarSelected => '已选择新头像';

  @override
  String get profileEditChangeAvatar => '更换头像';

  @override
  String get profileEditSectionDetails => '资料详情';

  @override
  String get profileEditDisplayNameLabel => '显示名称';

  @override
  String get profileEditDisplayNameRequired => '显示名称为必填项。';

  @override
  String get profileEditBioLabel => '简介 / 状态';

  @override
  String get profileTitleSelf => '我的资料';

  @override
  String get profileTitle => '个人资料';

  @override
  String get profileRetry => '重试';

  @override
  String get profileNotAvailable => '资料不可用。';

  @override
  String get profileLabelUserId => '用户 ID';

  @override
  String get profileLabelUsername => '用户名';

  @override
  String get profileLabelEmail => '邮箱';

  @override
  String get profileLabelRole => '角色';

  @override
  String get profileLabelMemberSince => '加入时间';

  @override
  String get profileEditComingSoon => '资料编辑功能即将上线';

  @override
  String get profileEditButton => '编辑资料';

  @override
  String get profileThisIsYou => '这是你';

  @override
  String get profileMessageButton => '发消息';

  @override
  String profileDateFormat(String month, int day, int year) {
    return '$year年$month$day日';
  }

  @override
  String get profileMonthJan => '1月';

  @override
  String get profileMonthFeb => '2月';

  @override
  String get profileMonthMar => '3月';

  @override
  String get profileMonthApr => '4月';

  @override
  String get profileMonthMay => '5月';

  @override
  String get profileMonthJun => '6月';

  @override
  String get profileMonthJul => '7月';

  @override
  String get profileMonthAug => '8月';

  @override
  String get profileMonthSep => '9月';

  @override
  String get profileMonthOct => '10月';

  @override
  String get profileMonthNov => '11月';

  @override
  String get profileMonthDec => '12月';

  @override
  String get settingsEditProfileTitle => '编辑资料';

  @override
  String get settingsEditProfileSubtitle => '更新显示名称、简介和头像';

  @override
  String get inboxTitle => '收件箱';

  @override
  String get inboxMarkAllReadTooltip => '全部标记已读';

  @override
  String get inboxLoadFailed => '加载收件箱失败';

  @override
  String get inboxRetry => '重试';

  @override
  String get inboxEmptyTitle => '全部已读！';

  @override
  String get inboxEmptySubtitle => '收件箱中没有消息';

  @override
  String get inboxActionMarkRead => '标为已读';

  @override
  String get inboxSwipeLabelRead => '已读';

  @override
  String get inboxFilterUnread => '未读';

  @override
  String get inboxFilterMentions => '@提及';

  @override
  String get inboxFilterDms => '私信';

  @override
  String get inboxFilterAll => '全部';

  @override
  String get inboxMentionBadge => '@你';

  @override
  String get inboxTimeNow => '刚刚';

  @override
  String inboxTimeMinutes(int count) {
    return '$count分钟';
  }

  @override
  String inboxTimeHours(int count) {
    return '$count小时';
  }

  @override
  String inboxTimeDays(int count) {
    return '$count天';
  }

  @override
  String get inboxUnreadCountOverflow => '99+';

  @override
  String get settingsAppearanceTitle => '外观';

  @override
  String get settingsAppearanceThemeSection => '主题';

  @override
  String get settingsThemeSystemTitle => '跟随系统';

  @override
  String get settingsThemeSystemDescription => '使用设备主题设置。';

  @override
  String get settingsThemeLightTitle => '浅色';

  @override
  String get settingsThemeLightDescription => '始终使用浅色主题。';

  @override
  String get settingsThemeDarkTitle => '深色';

  @override
  String get settingsThemeDarkDescription => '始终使用深色主题。';

  @override
  String get settingsDiagnosticsPageTitle => '诊断';

  @override
  String settingsDiagnosticsEntryCount(int count) {
    return '$count 条记录';
  }

  @override
  String get settingsDiagnosticsFilterAll => '全部';

  @override
  String get settingsDiagnosticsFilterInfo => '信息';

  @override
  String get settingsDiagnosticsFilterWarning => '警告';

  @override
  String get settingsDiagnosticsFilterError => '错误';

  @override
  String get settingsDiagnosticsEmpty => '没有诊断记录';

  @override
  String get settingsDiagnosticsWorkerLoading => '后台工作进程：加载中…';

  @override
  String get settingsDiagnosticsWorkerUnavailable => '后台工作进程诊断不可用';

  @override
  String get settingsDiagnosticsWorkerNotRunning => '后台工作进程：未运行';

  @override
  String get settingsDiagnosticsWorkerTitle => '后台工作进程';

  @override
  String get settingsTranslationPageTitle => '翻译';

  @override
  String get settingsTranslationNoActiveWorkspace => '没有活动的工作区。翻译设置属于工作区级别。';

  @override
  String get settingsTranslationRetry => '重试';

  @override
  String get settingsTranslationSectionMode => '翻译模式';

  @override
  String get settingsTranslationSectionLanguage => '首选语言';

  @override
  String get settingsTranslationModeAutoTitle => '自动';

  @override
  String get settingsTranslationModeManualTitle => '手动';

  @override
  String get settingsTranslationModeOffTitle => '关闭';

  @override
  String get settingsTranslationModeAutoDescription => '进入对话时自动翻译消息';

  @override
  String get settingsTranslationModeManualDescription => '仅在点击翻译按钮时翻译';

  @override
  String get settingsTranslationModeOffDescription => '翻译已禁用';

  @override
  String get billingTitle => '账单';

  @override
  String get billingUnavailableTitle => '账单不可用';

  @override
  String get billingUnavailableMessage => '当前无法加载账单详情。';

  @override
  String get billingCouldNotOpenManagement => '无法打开账单管理。';

  @override
  String get billingSubscriptionManagement => '订阅管理';

  @override
  String get billingSubscriptionManagementDesc => '查看当前订阅并在可用时打开账单门户。';

  @override
  String get billingSubscriptionSummary => '订阅概览';

  @override
  String get billingStatusUnavailable => '状态不可用';

  @override
  String get billingCurrentPrice => '当前价格';

  @override
  String get billingRenewalPeriod => '续期/周期';

  @override
  String get billingDetailsNotAvailable => '账单详情暂不可用。';

  @override
  String get billingManagementUnavailable => '账单管理不可用';

  @override
  String get billingOpenPortal => '打开账单门户';

  @override
  String get billingManagementUnavailableMessage =>
      '此工作区暂不支持账单管理。当服务器提供时，订阅详情将继续显示在此处。';

  @override
  String get billingManageSubscription => '通过账单门户管理您的订阅。';

  @override
  String get billingWorkspacePlanManagement => '工作区计划管理';

  @override
  String get billingWorkspacePlanDescActive => '查看当前工作区限制及升级或降级指引。';

  @override
  String get billingWorkspacePlanDescSelect => '选择工作区以查看服务器范围的账单限制和计划指引。';

  @override
  String get billingUsageSelectWorkspace => '工作区计划需要选择一个工作区';

  @override
  String get billingUsageSelectWorkspaceMessage => '选择工作区以查看当前用量、计划限制和升级指引。';

  @override
  String get billingUsageUnavailableTitle => '工作区用量不可用';

  @override
  String get billingUsageUnavailableMessage => '用量详情当前不可用。';

  @override
  String get billingServerUsageAndLimits => '服务器用量和限制';

  @override
  String get billingPlanDetailsUnavailable => '计划详情不可用';

  @override
  String get billingMessageHistory => '消息历史';

  @override
  String get billingPlanDowngraded => '工作区计划已降级';

  @override
  String billingPlanDowngradedMessage(String date) {
    return '此工作区计划于 $date 降级。升级以恢复更高限制。';
  }

  @override
  String get billingNeedMoreCapacity => '需要更多容量？';

  @override
  String get billingUpgradePortalMessage => '打开账单门户查看此工作区计划的升级选项。';

  @override
  String get billingUpgradeUnavailableMessage => '当此工作区支持账单管理时，升级选项将显示在此处。';

  @override
  String get billingMessageHistoryUnlimited => '无限制';

  @override
  String get billingMessageHistoryOneDay => '1 天';

  @override
  String billingMessageHistoryDays(int count) {
    return '$count 天';
  }

  @override
  String get threadsTitle => '话题';

  @override
  String get threadsEmpty => '还没有关注的话题。';

  @override
  String get threadsSwipeDone => '完成';

  @override
  String threadsRepliesCount(int count) {
    return '$count 条回复';
  }

  @override
  String threadsUnreadCount(int count) {
    return '$count 条未读';
  }

  @override
  String get threadsActionOpen => '打开话题';

  @override
  String get threadsActionDone => '完成';

  @override
  String get threadRepliesTitle => '话题回复';

  @override
  String get threadRepliesMissingContext => '缺少话题路由上下文。';

  @override
  String get threadRepliesRetry => '重试';

  @override
  String get threadRepliesFollowTooltip => '关注话题';

  @override
  String get threadRepliesDoneTooltip => '标记话题完成';

  @override
  String get dmsSortAZ => '按字母排序';

  @override
  String get dmsSortRecent => '按最近排序';

  @override
  String get dmsMarkAllRead => '全部标为已读';

  @override
  String get dmsClearSearch => '清除搜索';

  @override
  String get dmsMarkedUnread => '已标为未读';

  @override
  String get dmsNewMessageTitle => '新消息';

  @override
  String get dmsTabPeople => '成员';

  @override
  String get dmsTabAgents => '智能体';

  @override
  String get dmsSearchHint => '搜索...';

  @override
  String get dmsNoAgentsFound => '未找到智能体。';

  @override
  String get dmsNoMembersFound => '未找到成员。';

  @override
  String get dmsRetry => '重试';

  @override
  String get searchScopeAll => '全部';

  @override
  String get searchScopeMessages => '消息';

  @override
  String get searchScopeChannels => '频道';

  @override
  String get searchScopeContacts => '联系人';

  @override
  String get searchBadgeDm => '私信';

  @override
  String get searchBadgeChannel => '频道';

  @override
  String get conversationFilesTitle => '文件';

  @override
  String get conversationFilesRetry => '重试';

  @override
  String get conversationFilesEmpty => '此频道暂无文件';

  @override
  String get conversationQuoteLoading => '加载消息中…';

  @override
  String get conversationQuoteNotFound => '消息不可用';

  @override
  String conversationMemberCount(int count) {
    return '$count 位成员';
  }

  @override
  String get conversationCloseSearch => '关闭搜索';

  @override
  String get conversationSearchTooltip => '搜索';

  @override
  String get conversationInfoTooltip => '会话信息';

  @override
  String get conversationScreenshotTooltip => '截图';

  @override
  String get conversationMicDenied => '麦克风权限被拒绝。请在设置中启用。';

  @override
  String get conversationMicUnavailable => '无法开始录音。请检查麦克风可用性。';

  @override
  String conversationLoadFailed(String title) {
    return '无法加载 $title。';
  }

  @override
  String get conversationRetry => '重试';

  @override
  String conversationEmpty(String title) {
    return '$title 暂无消息。';
  }

  @override
  String get conversationPresenceOnline => '在线';

  @override
  String get conversationPresenceIdle => '空闲';

  @override
  String get conversationPresenceOffline => '离线';

  @override
  String get conversationOfflineBanner => '您已离线。重新连接后消息将被发送。';

  @override
  String get conversationInfoMute => '静音通知';

  @override
  String get conversationInfoMuted => '通知已静音';

  @override
  String get conversationInfoUnmuted => '接收所有通知';

  @override
  String get conversationInfoMembers => '成员';

  @override
  String get conversationInfoFiles => '共享文件';

  @override
  String get conversationInfoPinned => '置顶消息';

  @override
  String get conversationInfoProfileSection => '个人资料';

  @override
  String get conversationInfoDmSubtitle => '私信';

  @override
  String get conversationPinnedTitle => '置顶消息';

  @override
  String get conversationPinnedRetry => '重试';

  @override
  String get conversationPinnedEmpty => '暂无置顶消息';

  @override
  String get conversationMessageAiBadge => 'AI';

  @override
  String conversationMessageReplyCount(int count) {
    return '$count 条回复';
  }

  @override
  String get conversationMessageInThread => '在话题中';

  @override
  String get conversationCopiedToClipboard => '已复制到剪贴板。';

  @override
  String get conversationMessageForwarded => '消息已转发';

  @override
  String get conversationSendFailed => '发送失败。请重试。';

  @override
  String get conversationTaskCreated => '任务已创建。';

  @override
  String get conversationQuoteFallback => '[消息]';

  @override
  String get conversationProfileMessage => '发消息';

  @override
  String get conversationSearchHint => '在会话中搜索...';

  @override
  String get conversationSearchPrevious => '上一个结果';

  @override
  String get conversationSearchNext => '下一个结果';

  @override
  String get conversationSearchClose => '关闭搜索';

  @override
  String get conversationFormatBold => '粗体';

  @override
  String get conversationFormatItalic => '斜体';

  @override
  String get conversationFormatInlineCode => '行内代码';

  @override
  String get conversationFormatCodeBlock => '代码块';

  @override
  String get conversationFormatLink => '链接';

  @override
  String get conversationMessageListSemantics => '消息列表';

  @override
  String get membersTitle => '成员';

  @override
  String get membersRemoveTitle => '移除成员？';

  @override
  String get membersCancel => '取消';

  @override
  String get membersRemove => '移除';

  @override
  String get membersConfirm => '确认';

  @override
  String membersMemberRemoved(String name) {
    return '$name 已被移除。';
  }

  @override
  String get membersInviteCopied => '邀请链接已复制。';

  @override
  String get membersSend => '发送';

  @override
  String get membersGenerateLink => '生成链接';

  @override
  String get membersChangeRole => '更改角色';

  @override
  String get membersRoleAdmin => '管理员';

  @override
  String get membersRoleMember => '成员';

  @override
  String get membersMakeAdmin => '设为管理员';

  @override
  String get membersMakeMember => '设为成员';

  @override
  String get membersRemoveMember => '移除成员';

  @override
  String get membersProfileMessage => '发消息';

  @override
  String get savedMessagesRetry => '重试';

  @override
  String get biometricTryAgain => '重试';

  @override
  String get biometricDisableContinue => '禁用并继续';

  @override
  String get biometricSkipForNow => '暂时跳过';

  @override
  String get shareTargetTitle => '分享到...';

  @override
  String get translationFailed => '翻译失败。点击重试。';

  @override
  String membersRemoveBody(String name) {
    return '确定要将 $name 从此服务器中移除吗？';
  }

  @override
  String get membersEmailValidationError => '请输入有效的邮箱地址';

  @override
  String get membersInviteTitle => '邀请成员';

  @override
  String get membersInviteEmailSection => '发送邮件邀请';

  @override
  String get membersInviteEmailLabel => '邮箱';

  @override
  String get membersInviteEmailHint => 'user@example.com';

  @override
  String get membersInviteLinkSection => '或分享邀请链接';

  @override
  String get membersInviteCopyLink => '复制链接';

  @override
  String get membersRoleAdminSubtitle => '可以管理成员和邀请';

  @override
  String get membersRoleMemberSubtitle => '标准工作空间访问权限';

  @override
  String get savedMessagesTitle => '已保存';

  @override
  String get savedMessagesEmptyTitle => '没有已保存的消息';

  @override
  String get savedMessagesEmptySubtitle =>
      '长按消息并点击「保存」即可收藏。\n已保存的消息将显示在此处以供快速查阅。';

  @override
  String get savedMessagesUnsaveTooltip => '取消保存';

  @override
  String get savedMessagesSourceDm => '· 私信';

  @override
  String savedMessagesSourceChannel(String name) {
    return '· # $name';
  }

  @override
  String get biometricPrompt => '验证身份以继续使用 Slock';

  @override
  String get biometricLockTitle => '验证身份以继续';

  @override
  String get biometricLockSubtitle => '验证您的身份以访问 Slock';

  @override
  String get biometricErrorLockout => '尝试次数过多，请稍后再试。';

  @override
  String get biometricErrorPermanentLockout => '生物识别已锁定，请使用设备密码。';

  @override
  String get biometricErrorNotAvailable => '生物识别不可用，请重试。';

  @override
  String get biometricErrorNotEnrolled => '未注册生物识别，请重试。';

  @override
  String biometricErrorGeneric(int count) {
    return '认证失败。再试一次（$count/3）。';
  }

  @override
  String get shareSearchHint => '搜索对话...';

  @override
  String get shareSectionChannels => '频道';

  @override
  String get shareSectionDirectMessages => '私信';

  @override
  String get translationShowOriginal => '显示原文';

  @override
  String get translationShowTranslation => '显示翻译';

  @override
  String get translationPending => '翻译中…';

  @override
  String get notificationPrefAllTitle => '所有消息';

  @override
  String get notificationPrefAllDescription => '接收所有消息的通知。';

  @override
  String get notificationPrefMentionsTitle => '仅提及和私信';

  @override
  String get notificationPrefMentionsDescription => '仅接收私信的通知。';

  @override
  String get notificationPrefMuteTitle => '静音';

  @override
  String get notificationPrefMuteDescription => '不显示任何前台通知。';

  @override
  String get membersInviteHumanTooltip => '邀请成员';

  @override
  String get membersErrorTitle => '成员不可用';

  @override
  String get membersErrorMessage => '目前无法加载工作区成员。';

  @override
  String get membersEmptyMessage => '暂无成员。';

  @override
  String membersInviteSent(String email) {
    return '已向 $email 发送邀请邮件。';
  }

  @override
  String get membersSearchHint => '搜索成员…';

  @override
  String get membersSearchEmpty => '没有匹配的成员。';

  @override
  String get membersSectionHumans => '成员';

  @override
  String get membersSectionAgents => '智能体';

  @override
  String membersRoleChanged(String name, String role) {
    return '$name 现在是$role。';
  }

  @override
  String get membersRoleOwner => '所有者';

  @override
  String get homeSearchTooltip => '搜索';

  @override
  String get audioPlaybackFailed => '音频播放失败';

  @override
  String get crashRecoveryTitle => '应用已恢复';

  @override
  String get crashRecoveryMessage => '应用在上次会话中意外停止。您可以导出诊断日志帮助我们调查。';

  @override
  String get crashRecoveryContinue => '继续';

  @override
  String get crashRecoveryExport => '导出诊断日志';

  @override
  String get filePreviewShareFailed => '文件分享失败。';

  @override
  String get filePreviewShareTooltip => '分享';

  @override
  String get filePreviewOpenExternal => '在外部应用中打开';

  @override
  String get filePreviewRetry => '重试';

  @override
  String get filePreviewOpenWith => '打开方式…';

  @override
  String get annotationDraw => '画笔';

  @override
  String get annotationText => '文字';

  @override
  String get annotationArrow => '箭头';

  @override
  String get annotationUndo => '撤销';

  @override
  String get annotationRedo => '重做';

  @override
  String get annotationColorRed => '红色';

  @override
  String get annotationColorGreen => '绿色';

  @override
  String get annotationColorBlue => '蓝色';

  @override
  String get annotationColorYellow => '黄色';

  @override
  String get annotationColorWhite => '白色';

  @override
  String get annotationColorBlack => '黑色';

  @override
  String get voiceRecorderCancel => '取消录音';

  @override
  String get voiceRecorderSend => '发送语音消息';

  @override
  String get voiceMessageScrubber => '语音消息进度条';

  @override
  String get voiceBubblePause => '暂停';

  @override
  String get voiceBubblePlay => '播放';

  @override
  String get memberListItemMessageTooltip => '发消息';

  @override
  String get memberListItemAdminActionsTooltip => '成员管理操作';

  @override
  String get homeOverviewSemantics => '首页概览';

  @override
  String linkPreviewSemantics(String domain) {
    return '链接预览：$domain';
  }

  @override
  String get textPreviewShowMore => '展开更多';

  @override
  String get profileAvatarEditSemantics => '编辑头像';

  @override
  String get screenshotCanvasSemantics => '截图标注画布';

  @override
  String get voiceWaveformSemantics => '录音波形';

  @override
  String get unreadFilterLabel => '未读';

  @override
  String get allFilterLabel => '全部';

  @override
  String get agentEditTooltip => '编辑智能体';

  @override
  String get agentDeleteTooltip => '删除智能体';

  @override
  String get searchClearTooltip => '清除搜索';

  @override
  String get channelMembersAddTooltip => '添加成员';

  @override
  String get channelMembersRemoveTooltip => '移除成员';

  @override
  String get channelFilesTooltip => '频道文件';

  @override
  String get channelMembersTooltip => '频道成员';

  @override
  String get addHumanToChannelTooltip => '添加到频道';

  @override
  String get addAgentToChannelTooltip => '添加智能体到频道';

  @override
  String get togglePasswordVisibilityTooltip => '切换密码可见性';

  @override
  String get dismissAnnouncementTooltip => '关闭';

  @override
  String get shareTargetCancelTooltip => '取消';

  @override
  String get dmAgentBadge => '智能体';

  @override
  String get dmActionMoveUp => '上移';

  @override
  String get dmActionMoveDown => '下移';

  @override
  String get dmActionPin => '置顶对话';

  @override
  String get dmActionUnpin => '取消置顶';

  @override
  String get dmActionMarkUnread => '标为未读';

  @override
  String get dmActionClose => '关闭对话';

  @override
  String get taskOverlayDropTitle => '拖放以更改状态';

  @override
  String get taskOverlayCancelHint => '在方框外释放以取消';

  @override
  String taskOverlayMovedTo(String status) {
    return '已移至$status';
  }

  @override
  String get taskOverlayCurrentBadge => '当前';

  @override
  String get taskOverlayReleaseHint => '释放以移至此处';

  @override
  String get taskStatusTodo => '待办';

  @override
  String get taskStatusInProgress => '进行中';

  @override
  String get taskStatusInReview => '审核中';

  @override
  String get taskStatusDone => '已完成';

  @override
  String get taskStatusDescTodo => '未开始';

  @override
  String get taskStatusDescInProgress => '进行中';

  @override
  String get taskStatusDescInReview => '需要审核';

  @override
  String get taskStatusDescDone => '已完成';

  @override
  String get homeRetrySemantics => '重试';

  @override
  String get homeUnreadOverflowSemantics => '查看所有未读对话';

  @override
  String get homeServerSwitcherSemantics => '切换工作区';

  @override
  String get unreadFilterToggleSemantics => '切换未读筛选';

  @override
  String unreadListItemSemantics(String title) {
    return '打开对话：$title';
  }

  @override
  String get inboxItemSemantics => '打开通知';

  @override
  String inboxFilterTabSemantics(String label) {
    return '筛选：$label';
  }

  @override
  String searchScopeTabSemantics(String label) {
    return '搜索范围：$label';
  }

  @override
  String get filePreviewDismissSemantics => '下滑关闭';

  @override
  String messageLinkChipSemantics(String url) {
    return '打开链接：$url';
  }

  @override
  String get attachmentImageFallbackSemantics => '图片附件';

  @override
  String get navInbox => '收件箱';

  @override
  String get homeAppBarFallbackTitle => 'Slock';

  @override
  String get homeTypePillThread => '话题';

  @override
  String get homeTypePillChannel => '频道';

  @override
  String get homeTypePillDm => '私信';

  @override
  String get unreadOtherSources => '其他未读来源';

  @override
  String routerPageNotFound(String uri) {
    return '页面未找到：$uri';
  }

  @override
  String get shareSendFailed => '发送失败，请重试。';

  @override
  String get filePreviewFallbackTitle => '文件预览';

  @override
  String get filePreviewFallbackBody => '文件预览不可用';

  @override
  String get filePreviewFallbackBack => '返回';

  @override
  String get errorRetry => '重试';

  @override
  String get errorShareDiagnostics => '分享诊断信息';

  @override
  String get fatalTitle => '无法启动';

  @override
  String get fatalBodyMissingConfig => '应用缺少必要的配置，无法启动。这通常意味着构建时未提供必要的环境设置。';

  @override
  String get fatalBodyGeneric => '启动过程中出现问题，请尝试重新启动应用。';

  @override
  String get fatalHintDeveloper => '如果您是开发者，请确保构建时提供了所有必要的 --dart-define 值。';

  @override
  String get fatalHintGeneric => '如果问题持续存在，请重新安装应用或联系支持。';

  @override
  String get fatalCopyDiagnostics => '复制诊断信息';

  @override
  String get fatalDiagnosticsCopied => '诊断信息已复制到剪贴板';

  @override
  String get diagExportTitle => '导出诊断信息';

  @override
  String get diagExportSubtitle => '将诊断日志分享给开发团队。';

  @override
  String get diagCopyToClipboard => '复制到剪贴板';

  @override
  String get diagShare => '分享';

  @override
  String get diagSaveToFile => '保存到文件';

  @override
  String get diagCopied => '已复制到剪贴板';

  @override
  String get diagCopyFailed => '复制失败';

  @override
  String get diagShared => '分享成功';

  @override
  String get diagShareFailed => '分享失败';

  @override
  String diagSaved(String path) {
    return '已保存到 $path';
  }

  @override
  String get diagSaveFailed => '保存失败';

  @override
  String get filePreviewNoUrl => '没有可用的下载链接。';

  @override
  String get filePreviewLoadFailed => '加载附件失败。';

  @override
  String get filePreviewPdfDownloadFailed => '下载 PDF 失败。';

  @override
  String get filePreviewDownloadingPdf => '正在下载 PDF…';

  @override
  String get filePreviewLoading => '加载中…';

  @override
  String get filePreviewPdfUnavailable => 'PDF 文件不可用。';

  @override
  String get filePreviewPdfRenderFailed => 'PDF 渲染失败。';

  @override
  String get filePreviewImageLoadFailed => '无法加载图片。';

  @override
  String get avatarUploadInvalidResponse => '服务器返回无效响应。';

  @override
  String get avatarUploadFailed => '上传失败。';

  @override
  String get avatarUploadFailedRetry => '上传失败，请重试。';

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int count) {
    return '$count分钟前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count小时前';
  }

  @override
  String get billingResourceAgents => '智能体';

  @override
  String get billingResourceMachines => '机器';

  @override
  String get billingResourceChannels => '频道';

  @override
  String get notificationNewMessageFallback => '新消息';

  @override
  String typingIndicatorOne(String name) {
    return '$name 正在输入...';
  }

  @override
  String typingIndicatorTwo(String first, String second) {
    return '$first 和 $second 正在输入...';
  }

  @override
  String get typingIndicatorSeveral => '多人正在输入...';

  @override
  String typingIndicatorThreeOrMore(String allButLast, String last) {
    return '$allButLast 和 $last 正在输入...';
  }

  @override
  String get connectionReconnecting => '重新连接中...';

  @override
  String get conversationDefaultTitleDm => '私信';

  @override
  String get userFallbackDisplayName => '用户';

  @override
  String get agentsActivityLogOnline => '在线';

  @override
  String get agentsActivityLogThinking => '思考中';

  @override
  String get agentsActivityLogWorking => '工作中';

  @override
  String get agentsActivityLogError => '错误';

  @override
  String agentsActivityLogErrorDetail(String detail) {
    return '错误：$detail';
  }

  @override
  String get agentsActivityLogOffline => '离线';

  @override
  String get senderLabelAgent => '机器人';

  @override
  String get senderLabelMember => '成员';

  @override
  String get senderLabelSystem => '系统';

  @override
  String get senderLabelUnknown => '未知';

  @override
  String sharePreviewAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个附件',
      one: '1 个附件',
    );
    return '$_temp0';
  }

  @override
  String get inboxFallbackDmName => '未知';

  @override
  String get inboxFallbackMemberName => '成员';
}
