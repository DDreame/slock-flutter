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
}
