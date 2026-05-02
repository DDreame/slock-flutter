// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Slock';

  @override
  String get splashTitle => 'Slock';

  @override
  String get splashSubtitle => 'Preparing your workspace...';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginSubmitLabel => 'Login';

  @override
  String get loginCreateAccountCta => 'Create account';

  @override
  String get loginForgotPasswordCta => 'Forgot password?';

  @override
  String get loginEmailRequiredError => 'Email is required.';

  @override
  String get loginEmailInvalidError => 'Enter a valid email address.';

  @override
  String get loginPasswordRequiredError => 'Password is required.';

  @override
  String get loginFailedFallback => 'Login failed. Please try again.';

  @override
  String get registerTitle => 'Register';

  @override
  String get registerDisplayNameLabel => 'Display name';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerPasswordLabel => 'Password';

  @override
  String get registerSubmitLabel => 'Register';

  @override
  String get registerAlreadyHaveAccountCta => 'Already have an account? Login';

  @override
  String get registerDisplayNameRequiredError => 'Display name is required.';

  @override
  String get registerEmailRequiredError => 'Email is required.';

  @override
  String get registerEmailInvalidError => 'Enter a valid email address.';

  @override
  String get registerPasswordTooShortError =>
      'Password must be at least 8 characters.';

  @override
  String get registerFailedFallback => 'Registration failed. Please try again.';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordSuccessTitle => 'Check your email';

  @override
  String get forgotPasswordSuccessMessage =>
      'If that email is registered, a reset link has been sent. Check your inbox.';

  @override
  String get forgotPasswordEmailLabel => 'Email';

  @override
  String get forgotPasswordSubmitLabel => 'Reset Password';

  @override
  String get forgotPasswordBackToLogin => 'Back to login';

  @override
  String get forgotPasswordEmailRequiredError => 'Email is required.';

  @override
  String get forgotPasswordEmailInvalidError => 'Enter a valid email address.';

  @override
  String get forgotPasswordFailedFallback =>
      'Failed to send reset email. Please try again.';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get resetPasswordCompletedMessage =>
      'Password reset complete. You can now sign in with your new password.';

  @override
  String get resetPasswordNewPasswordLabel => 'New password';

  @override
  String get resetPasswordConfirmPasswordLabel => 'Confirm new password';

  @override
  String get resetPasswordSubmitLabel => 'Set new password';

  @override
  String get resetPasswordBackToLogin => 'Back to login';

  @override
  String get resetPasswordLinkInvalidError =>
      'Reset link is missing or invalid.';

  @override
  String get resetPasswordTooShortError =>
      'Password must be at least 8 characters.';

  @override
  String get resetPasswordMismatchError => 'Passwords do not match.';

  @override
  String get resetPasswordFailedFallback =>
      'Password reset failed. The link may be expired.';

  @override
  String get verifyEmailTitle => 'Verify Email';

  @override
  String get verifyEmailInstructions => 'Verify your email to continue.';

  @override
  String get verifyEmailResentMessage =>
      'Verification email resent. Check your inbox.';

  @override
  String get verifyEmailResendButton => 'Resend verification email';

  @override
  String get verifyEmailTokenLabel => 'Verification token';

  @override
  String get verifyEmailSubmitLabel => 'Verify';

  @override
  String get verifyEmailSuccessMessage =>
      'Email verified. You can continue to the app.';

  @override
  String get verifyEmailContinueButton => 'Continue to Slock';

  @override
  String get verifyEmailSignOut => 'Sign out';

  @override
  String get verifyEmailBackToLogin => 'Back to login';

  @override
  String get verifyEmailTokenRequiredError => 'Enter a verification token.';

  @override
  String get verifyEmailFailedFallback =>
      'Verification failed. The link may be expired.';

  @override
  String get verifyEmailResendFailedFallback =>
      'Failed to resend verification email.';

  @override
  String get navWorkspace => 'Home';

  @override
  String get navChannels => 'Channels';

  @override
  String get navDms => 'Messages';

  @override
  String get navAgents => 'Agents';

  @override
  String get agentsNewTooltip => 'New agent';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeWorkspaceConsole => 'Workspace Console';

  @override
  String get homeConsoleActivityTitle => 'Activity';

  @override
  String get homeConsoleActivityDescription =>
      'Saved context, threads, tasks, and search.';

  @override
  String get homeConsoleSavedMessages => 'Saved Messages';

  @override
  String get homeConsoleSavedMessagesDescription =>
      'Return to bookmarked updates and references.';

  @override
  String get homeConsoleThreads => 'Threads';

  @override
  String get homeConsoleThreadsDescription =>
      'Review active thread work across the workspace.';

  @override
  String get homeConsoleTasks => 'Tasks';

  @override
  String get homeConsoleTasksDescription =>
      'See task queues and execution status.';

  @override
  String get homeConsoleSearch => 'Search';

  @override
  String get homeConsoleSearchDescription =>
      'Find channels, messages, and workspace history.';

  @override
  String get homeConsoleOperationsTitle => 'Operations';

  @override
  String get homeConsoleOperationsDescription =>
      'People, infrastructure, billing, and settings.';

  @override
  String get homeConsoleMembers => 'Members';

  @override
  String get homeConsoleMembersDescription =>
      'Manage workspace roles and invitations.';

  @override
  String get homeConsoleAgentControl => 'Agent Control';

  @override
  String get homeConsoleAgentControlDescription =>
      'Inspect agent activity and assignments.';

  @override
  String get homeConsoleMachines => 'Machines';

  @override
  String get homeConsoleMachinesDescription =>
      'Check workspace runtime capacity and hosts.';

  @override
  String get homeConsoleBilling => 'Billing';

  @override
  String get homeConsoleBillingDescription =>
      'Review plan controls and billing management.';

  @override
  String get homeConsoleWorkspaceSettings => 'Workspace Settings';

  @override
  String get homeConsoleWorkspaceSettingsDescription =>
      'Configure workspace-level defaults and access.';

  @override
  String get homeCardAgents => 'AGENTS';

  @override
  String get homeCardAgentsSubtitle => 'agents in workspace';

  @override
  String homeCardAgentsOnline(int count) {
    return '$count online';
  }

  @override
  String homeCardAgentsError(int count) {
    return '$count error';
  }

  @override
  String homeCardAgentsStopped(int count) {
    return '$count stopped';
  }

  @override
  String homeCardAgentsIdle(int count) {
    return '$count idle';
  }

  @override
  String get homeCardAgentsEmpty => 'All agents idle';

  @override
  String get homeCardChannels => 'CHANNELS';

  @override
  String get homeCardChannelsSubtitle => 'active channels';

  @override
  String homeCardChannelsUnread(int count) {
    return '$count unread';
  }

  @override
  String get homeCardTasks => 'TASKS';

  @override
  String get homeCardTasksSubtitle => 'total tasks';

  @override
  String get homeCardTasksEmpty => 'No active tasks';

  @override
  String homeCardTasksOverflow(int count) {
    return '+$count more';
  }

  @override
  String get homeCardTasksInProgress => 'In Progress';

  @override
  String get homeCardTasksTodo => 'To Do';

  @override
  String homeCardTasksDurationMinutes(int count) {
    return '${count}m';
  }

  @override
  String homeCardTasksDurationHours(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String homeCardTasksDurationHoursOnly(int count) {
    return '${count}h';
  }

  @override
  String get homeCardThreads => 'THREADS';

  @override
  String get homeCardViewAll => 'View all';

  @override
  String get homeCardThreadsFilterUnread => 'Unread';

  @override
  String get homeCardThreadsFilterRead => 'Read';

  @override
  String get homeCardThreadsFilterAll => 'All';

  @override
  String homeCardThreadsReplies(int count) {
    return '$count replies';
  }

  @override
  String homeCardThreadsNew(int count) {
    return '$count new';
  }

  @override
  String get homeCardThreadsEmpty => 'No threads';

  @override
  String get homeCardAgentActivityIdle => 'idle';

  @override
  String get homeCardAgentActivityThinking => 'thinking';

  @override
  String get homeCardAgentActivityWorking => 'working';

  @override
  String get homeCardAgentActivityError => 'error';

  @override
  String get homeCardAgentActivityOffline => 'offline';

  @override
  String get homeCardTimeAgoNow => 'now';

  @override
  String homeCardTimeAgoMinutes(int count) {
    return '${count}m ago';
  }

  @override
  String homeCardTimeAgoHours(int count) {
    return '${count}h ago';
  }

  @override
  String homeCardTimeAgoDays(int count) {
    return '${count}d ago';
  }

  @override
  String get homeCardUnread => 'UNREAD';

  @override
  String get homeCardUnreadEmpty => 'All caught up';

  @override
  String homeCardUnreadOverflow(int count) {
    return '+$count more';
  }

  @override
  String homeCardUnreadBadge(int count) {
    return '$count';
  }

  @override
  String get homeCardUnreadMarkAllRead => 'Mark all read';

  @override
  String get homeSectionPinned => 'Pinned';

  @override
  String get homeSectionChannels => 'Channels';

  @override
  String get homeSectionDirectMessages => 'Direct Messages';

  @override
  String get homeSectionPinnedAgents => 'Pinned Agents';

  @override
  String get homeSectionAgents => 'Agents';

  @override
  String get homeChannelsEmpty => 'No channels yet.';

  @override
  String get homeDirectMessagesEmpty => 'No direct messages yet.';

  @override
  String get homeCreateChannelTooltip => 'Create channel';

  @override
  String get homeNewMessageTooltip => 'New message';

  @override
  String homeHiddenConversationsCount(int count) {
    return 'Hidden conversations ($count)';
  }

  @override
  String get homeHiddenConversationsTitle => 'Hidden conversations';

  @override
  String get homeUnhide => 'Unhide';

  @override
  String get homePin => 'Pin';

  @override
  String get homeUnpin => 'Unpin';

  @override
  String get homeNoServerMessage => 'Select a server to get started.';

  @override
  String get homeSelectWorkspace => 'Select workspace';

  @override
  String get homeLoadFailedFallback => 'Unable to load conversations.';

  @override
  String get homeRetry => 'Retry';

  @override
  String get channelsTabTitle => 'Channels';

  @override
  String get channelsTabPlaceholder =>
      'Channel list will be available here soon.';

  @override
  String get channelsTabSearchHint => 'Search channels';

  @override
  String get channelsTabEmpty => 'No channels yet.';

  @override
  String get dmsTabTitle => 'Messages';

  @override
  String get dmsTabHeadline => 'Direct Messages';

  @override
  String get dmsTabPlaceholder =>
      'Direct messages will be available here soon.';

  @override
  String get dmsTabSearchHint => 'Search messages';

  @override
  String get dmsTabEmpty => 'No direct messages yet.';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get homeChannelCreated => 'Channel created.';

  @override
  String get homeChannelCreateFailed => 'Failed to create channel.';

  @override
  String get homeChannelUpdated => 'Channel updated.';

  @override
  String get homeChannelUpdateFailed => 'Failed to update channel.';

  @override
  String get homeDeleteChannelTitle => 'Delete channel';

  @override
  String homeDeleteChannelMessage(String name) {
    return 'Delete $name? This cannot be undone.';
  }

  @override
  String get homeDeleteChannelConfirm => 'Delete';

  @override
  String get homeChannelDeleted => 'Channel deleted.';

  @override
  String get homeChannelDeleteFailed => 'Failed to delete channel.';

  @override
  String get homeLeaveChannelTitle => 'Leave channel';

  @override
  String homeLeaveChannelMessage(String name) {
    return 'Leave $name?';
  }

  @override
  String get homeLeaveChannelConfirm => 'Leave';

  @override
  String get homeChannelLeft => 'Left channel.';

  @override
  String get homeChannelLeaveFailed => 'Failed to leave channel.';

  @override
  String get baseUrlSettingsTitle => 'Server Configuration';

  @override
  String get baseUrlSettingsSubtitle =>
      'Configure custom API and WebSocket endpoints.';

  @override
  String get baseUrlApiLabel => 'API Base URL';

  @override
  String get baseUrlApiHint => 'https://api.example.com';

  @override
  String get baseUrlRealtimeLabel => 'Realtime URL';

  @override
  String get baseUrlRealtimeHint => 'wss://realtime.example.com';

  @override
  String get baseUrlSave => 'Save';

  @override
  String get baseUrlRestoreDefaults => 'Restore defaults';

  @override
  String get baseUrlTestConnection => 'Test connection';

  @override
  String get baseUrlTesting => 'Testing…';

  @override
  String get baseUrlSaved =>
      'Settings saved. Restart the app to apply changes.';

  @override
  String get baseUrlRestored =>
      'Defaults restored. Restart the app to apply changes.';

  @override
  String get baseUrlApiInvalidError => 'Enter a valid http:// or https:// URL.';

  @override
  String get baseUrlRealtimeInvalidError =>
      'Enter a valid ws://, wss://, http://, or https:// URL.';

  @override
  String get baseUrlResultReachable => 'Reachable';

  @override
  String get baseUrlResultUnauthorized => 'Reachable (unauthorized)';

  @override
  String get baseUrlResultTimeout => 'Timeout';

  @override
  String get baseUrlResultInvalid => 'Invalid URL';

  @override
  String get baseUrlEmptyDefault => 'Using build-time default';

  @override
  String get baseUrlRestartRequired => 'Restart required to apply changes.';

  @override
  String get baseUrlSettingsSettingsTile => 'Server';

  @override
  String get baseUrlSettingsSettingsTileSubtitle =>
      'Custom API and WebSocket endpoints.';

  @override
  String get attachmentOpenInBrowser => 'Open in browser';

  @override
  String get attachmentUnableToLoadImage => 'Unable to load image';

  @override
  String get attachmentHtmlOpensInBrowser => 'HTML • Opens in browser';
}
