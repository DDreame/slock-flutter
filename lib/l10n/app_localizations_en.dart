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
  String get agentsNoMachineAssigned => 'No Machine Assigned';

  @override
  String get releaseNotesTitle => 'Release Notes';

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
  String get homeCardAgentsEmpty => 'All agents offline';

  @override
  String get homeCardTasks => 'TASKS';

  @override
  String get homeCardTasksSubtitle => 'total tasks';

  @override
  String get homeCardTasksEmpty => 'No active tasks';

  @override
  String get homeCardTasksUnavailable => 'Tasks unavailable';

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
  String get homeCardViewAll => 'View all';

  @override
  String get homeCardAgentActivityOnline => 'online';

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

  @override
  String get refreshFailedSnackbar => 'Could not refresh. Showing cached data.';

  @override
  String get refreshFailedRetry => 'Retry';

  @override
  String get workspaceSettingsUnavailableTitle =>
      'Workspace settings unavailable';

  @override
  String get workspaceSettingsUnavailableMessage =>
      'We could not load workspace settings right now.';

  @override
  String get workspaceSettingsNotFound => 'Workspace not found.';

  @override
  String get workspaceSettingsRoleLabel => 'Role';

  @override
  String get workspaceSettingsRoleUnknown => 'Unknown';

  @override
  String get workspaceSettingsCreatedLabel => 'Created';

  @override
  String get workspaceSettingsManageSection => 'Manage';

  @override
  String get workspaceSettingsActionsSection => 'Actions';

  @override
  String get workspaceSettingsRenameAction => 'Rename workspace';

  @override
  String get workspaceSettingsDeleteAction => 'Delete workspace';

  @override
  String get workspaceSettingsLeaveAction => 'Leave workspace';

  @override
  String get workspaceSettingsRenamedSnackbar => 'Workspace renamed.';

  @override
  String get workspaceSettingsRenameFailed => 'Failed to rename workspace.';

  @override
  String get workspaceSettingsDeleteDialogTitle => 'Delete workspace?';

  @override
  String workspaceSettingsDeleteDialogMessage(String name) {
    return 'Delete $name? This permanently removes the workspace and all its data.';
  }

  @override
  String get workspaceSettingsDeleteConfirmLabel => 'Delete';

  @override
  String get workspaceSettingsDeleteFailed => 'Failed to delete workspace.';

  @override
  String get workspaceSettingsLeaveDialogTitle => 'Leave workspace?';

  @override
  String workspaceSettingsLeaveDialogMessage(String name) {
    return 'Leave $name? You can rejoin later with a new invite.';
  }

  @override
  String get workspaceSettingsLeaveConfirmLabel => 'Leave';

  @override
  String get workspaceSettingsLeaveFailed => 'Failed to leave workspace.';

  @override
  String get previewDeleted => 'Message deleted';

  @override
  String get previewSending => 'Sending…';

  @override
  String get previewFailed => 'Not sent, tap to retry';

  @override
  String get previewSystem => 'System message';

  @override
  String get previewLink => 'Link';

  @override
  String get previewVoice => 'Voice message';

  @override
  String get previewImage => 'Image';

  @override
  String get previewVideo => 'Video';

  @override
  String get previewFallback => 'New message';

  @override
  String previewAttachment(String name) {
    return 'Attachment: $name';
  }

  @override
  String get agentStatusThinking => 'Thinking';

  @override
  String get agentStatusWorking => 'Working';

  @override
  String get agentStatusError => 'Error';

  @override
  String get agentStatusOnline => 'Online';

  @override
  String get agentStatusOffline => 'Offline';

  @override
  String get agentStatusStopped => 'Stopped';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsWorkspaceSection => 'Workspace';

  @override
  String get settingsNotificationsSection => 'Notifications';

  @override
  String get settingsAppearanceSection => 'Appearance';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsSecuritySection => 'Security';

  @override
  String get settingsMoreSection => 'More';

  @override
  String get settingsDangerZoneSection => 'Danger Zone';

  @override
  String get settingsMyProfileTitle => 'My Profile';

  @override
  String get settingsMyProfileSubtitle =>
      'Review your current account details.';

  @override
  String get settingsMembersTitle => 'Members';

  @override
  String get settingsMembersSubtitle => 'View and manage workspace members.';

  @override
  String get settingsNotificationSettingsTitle => 'Notification Settings';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsTranslationTitle => 'Translation';

  @override
  String get settingsTranslationSubtitle =>
      'Preferred language and translation mode.';

  @override
  String get settingsBiometricLockTitle => 'Biometric Lock';

  @override
  String get settingsBiometricLockEnabled =>
      'Enabled — unlock with biometrics after inactivity';

  @override
  String get settingsBiometricLockDisabled =>
      'Disabled — no biometric lock on app access';

  @override
  String get settingsBillingTitle => 'Billing';

  @override
  String get settingsBillingSubtitle =>
      'Review your current subscription summary.';

  @override
  String get settingsReleaseNotesTitle => 'Release Notes';

  @override
  String get settingsReleaseNotesSubtitle =>
      'See the latest packaged product updates.';

  @override
  String get settingsDiagnosticsTitle => 'Diagnostics';

  @override
  String get settingsDiagnosticsSubtitle => 'View and export diagnostic logs.';

  @override
  String get settingsLogOutTitle => 'Log Out';

  @override
  String get settingsLogOutSubtitle => 'Sign out of this device.';

  @override
  String get settingsLogOutDialogTitle => 'Log out?';

  @override
  String get settingsLogOutDialogContent =>
      'You will be signed out of this device.';

  @override
  String get settingsLogOutDialogCancel => 'Cancel';

  @override
  String get settingsLogOutDialogConfirm => 'Log out';

  @override
  String get settingsSignedInFallback => 'Signed in';

  @override
  String get settingsAccountUnavailable => 'Account details unavailable';

  @override
  String get settingsNotificationGranted => 'Granted';

  @override
  String get settingsNotificationDenied => 'Denied';

  @override
  String get settingsNotificationProvisional => 'Provisional';

  @override
  String get settingsNotificationNotRequested => 'Not requested';

  @override
  String get notificationSettingsTitle => 'Notification Settings';

  @override
  String get notificationSettingsPermissionSection => 'Permission';

  @override
  String get notificationSettingsPushNotifications => 'Push Notifications';

  @override
  String get notificationSettingsFilterSection => 'Notification Filter';

  @override
  String get notificationSettingsDiagnosticsSection => 'Diagnostics';

  @override
  String get notificationSettingsDeviceToken => 'Device Token';

  @override
  String get notificationSettingsPlatform => 'Platform';

  @override
  String get notificationSettingsLastRegistration => 'Last Registration';

  @override
  String get notificationSettingsPermissionStatus => 'Permission Status';

  @override
  String get notificationSettingsRecentEvents => 'Recent Events';

  @override
  String get notificationSettingsNoEvents => 'No recent notification events.';

  @override
  String get notificationSettingsNotAvailable => 'Not available';

  @override
  String get notificationSettingsNotRegistered => 'Not registered yet';

  @override
  String get notificationSettingsUpdateFailed =>
      'Could not update notification settings.';

  @override
  String get notificationSettingsRefreshRegistration =>
      'Refresh Device Registration';

  @override
  String get notificationSettingsRetryAccess => 'Retry Notification Access';

  @override
  String get notificationSettingsEnable => 'Enable Push Notifications';

  @override
  String get notificationSettingsPermissionGranted => 'Permission granted';

  @override
  String get notificationSettingsPermissionDenied => 'Permission denied';

  @override
  String get notificationSettingsPermissionProvisional =>
      'Permission provisional';

  @override
  String get notificationSettingsPermissionUnknown =>
      'Permission not requested yet';

  @override
  String notificationSettingsDeviceRegistered(String date) {
    return 'Device registered $date.';
  }

  @override
  String get notificationSettingsDeviceNotRegistered =>
      'Device registration not available yet.';

  @override
  String get notificationSettingsDateRecently => 'recently';

  @override
  String get notificationSettingsResultGranted =>
      'Notification access granted and device registration refreshed.';

  @override
  String get notificationSettingsResultProvisional =>
      'Notification access is provisional; device registration refreshed.';

  @override
  String get notificationSettingsResultDenied =>
      'Notification access was denied.';

  @override
  String get notificationSettingsResultUnknown =>
      'Notification status is still unavailable on this device.';

  @override
  String get searchHintText => 'Search messages, channels, or contacts...';

  @override
  String get searchIdleText =>
      'Type to search messages, channels, or contacts.';

  @override
  String get searchNoResults => 'No results found.';

  @override
  String get searchRetry => 'Retry';

  @override
  String get searchFailedFallback => 'Search failed.';

  @override
  String get searchSectionChannels => 'Channels';

  @override
  String get searchSectionContacts => 'Contacts';

  @override
  String get searchSectionMessages => 'Messages';

  @override
  String get searchViewAll => 'View all';

  @override
  String get searchLoadMore => 'Load more';

  @override
  String get searchFilterSender => 'Sender';

  @override
  String get searchFilterChannel => 'Channel';

  @override
  String get searchFilterClear => 'Clear';

  @override
  String get searchFilterNewest => 'Newest';

  @override
  String get searchFilterOldest => 'Oldest';

  @override
  String get searchFilterBySenderTitle => 'Filter by sender';

  @override
  String get searchFilterBySenderHint => 'Enter sender name…';

  @override
  String get searchFilterByChannelTitle => 'Filter by channel';

  @override
  String get searchFilterByChannelHint => 'Enter channel name…';

  @override
  String get searchFilterCancel => 'Cancel';

  @override
  String get searchFilterApply => 'Apply';

  @override
  String get searchFilterDateAny => 'Any time';

  @override
  String get searchFilterDateToday => 'Today';

  @override
  String get searchFilterDateWeek => 'Past week';

  @override
  String get searchFilterDateMonth => 'Past month';

  @override
  String get searchCouldNotOpenConversation => 'Could not open conversation.';

  @override
  String searchFilterFromPrefix(String name) {
    return 'From: $name';
  }

  @override
  String searchFilterInPrefix(String name) {
    return 'In: $name';
  }

  @override
  String get searchRecentTitle => 'Recent';

  @override
  String get searchRecentClear => 'Clear';

  @override
  String get machinesPageTitle => 'Machines';

  @override
  String get machinesAddButton => 'Add Machine';

  @override
  String get machinesLoadFailed => 'Failed to load machines.';

  @override
  String get machinesRegisterTitle => 'Register Machine';

  @override
  String get machinesRegisterAction => 'Register';

  @override
  String get machinesRegisterHelper =>
      'Create a machine and reveal its API key once.';

  @override
  String get machinesRegisteredTitle => 'Machine Registered';

  @override
  String get machinesRegisterFailed => 'Failed to register machine.';

  @override
  String get machinesRenameTitle => 'Rename Machine';

  @override
  String get machinesRenameSaveAction => 'Save';

  @override
  String get machinesRenameHelper =>
      'Update the machine label shown across the workspace.';

  @override
  String get machinesRenamedSnackbar => 'Machine renamed.';

  @override
  String get machinesRenameFailed => 'Failed to rename machine.';

  @override
  String get machinesRotatedApiKeyTitle => 'Rotated API Key';

  @override
  String get machinesRotateApiKeyFailed => 'Failed to rotate machine API key.';

  @override
  String get machinesDeleteTitle => 'Delete Machine?';

  @override
  String get machinesDeleteCancel => 'Cancel';

  @override
  String get machinesDeleteConfirm => 'Delete';

  @override
  String get machinesDeletedSnackbar => 'Machine deleted.';

  @override
  String get machinesDeleteFailed => 'Failed to delete machine.';

  @override
  String get machinesApiKeyRevealedNote =>
      'This key is only revealed at creation or rotation time.';

  @override
  String get machinesApiKeyCopied => 'API key copied.';

  @override
  String get machinesCopyButton => 'Copy';

  @override
  String get machinesDoneButton => 'Done';

  @override
  String get machinesRetryButton => 'Retry';

  @override
  String get machinesLatestDaemon => 'Latest daemon';

  @override
  String get machinesEmptyTitle => 'No machines registered yet.';

  @override
  String get machinesEmptyDescription =>
      'Register a machine to attach runtimes and admin operations to this server.';

  @override
  String get machinesRegisterButton => 'Register Machine';

  @override
  String get machinesMenuRename => 'Rename';

  @override
  String get machinesMenuRotateApiKey => 'Rotate API Key';

  @override
  String get machinesMenuDelete => 'Delete';

  @override
  String get machinesMetaHost => 'Host';

  @override
  String get machinesMetaOs => 'OS';

  @override
  String get machinesMetaDaemon => 'Daemon';

  @override
  String get machinesStatusOnline => 'Online';

  @override
  String get machinesStatusOffline => 'Offline';

  @override
  String get machinesStatusError => 'Error';

  @override
  String get machinesNameLabel => 'Machine name';

  @override
  String get machinesNameDialogCancel => 'Cancel';

  @override
  String machinesDeleteMessage(String name) {
    return 'Delete $name? This removes the machine from the server list.';
  }

  @override
  String machinesCopyApiKeyMessage(String name) {
    return 'Copy the API key for $name now.';
  }

  @override
  String machinesSummaryCount(int count) {
    return '$count machine(s)';
  }

  @override
  String machinesSummaryOnline(int count) {
    return '$count online';
  }

  @override
  String machinesApiKeyPrefix(String prefix) {
    return 'Key $prefix...';
  }

  @override
  String get machinesMenuWorkspaces => 'Workspaces';

  @override
  String get workspacesPageTitle => 'Workspaces';

  @override
  String get workspacesEmpty => 'No workspaces on this machine.';

  @override
  String get workspacesLoadFailed => 'Failed to load workspaces.';

  @override
  String get workspacesRetryButton => 'Retry';

  @override
  String get workspacesDeleteTitle => 'Delete Workspace?';

  @override
  String workspacesDeleteMessage(String name) {
    return 'Delete workspace \"$name\"? This cannot be undone.';
  }

  @override
  String get workspacesDeleteCancel => 'Cancel';

  @override
  String get workspacesDeleteConfirm => 'Delete';

  @override
  String get workspacesDeletedSnackbar => 'Workspace deleted.';

  @override
  String get workspacesDeleteFailed => 'Failed to delete workspace.';

  @override
  String get workspacesMetaPath => 'Path';

  @override
  String get workspacesMetaAgent => 'Agent';

  @override
  String get workspacesStatusActive => 'Active';

  @override
  String get workspacesStatusInactive => 'Inactive';

  @override
  String get tasksLoadFailed => 'Failed to load tasks.';

  @override
  String get tasksEmptyAll => 'No tasks yet.';

  @override
  String get tasksNoChannelsAvailable => 'No channels available.';

  @override
  String get tasksCreatedSnackbar => 'Task created.';

  @override
  String get tasksCreateFailed => 'Failed to create task.';

  @override
  String get tasksUpdateFailed => 'Failed to update task.';

  @override
  String get tasksRetryAction => 'RETRY';

  @override
  String get tasksDeleteTitle => 'Delete Task?';

  @override
  String tasksDeleteMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get tasksDeleteCancel => 'Cancel';

  @override
  String get tasksDeleteConfirm => 'Delete';

  @override
  String get tasksDeletedSnackbar => 'Task deleted.';

  @override
  String get tasksDeleteFailed => 'Failed to delete task.';

  @override
  String get tasksClaimFailed => 'Failed to claim task.';

  @override
  String get tasksUnclaimFailed => 'Failed to unclaim task.';

  @override
  String get tasksHeaderTitle => 'Tasks';

  @override
  String get tasksNewButton => 'New';

  @override
  String get tasksSummaryTodo => 'To Do';

  @override
  String get tasksSummaryInProgress => 'In Progress';

  @override
  String get tasksSummaryReview => 'Review';

  @override
  String get tasksSummaryDone => 'Done';

  @override
  String get tasksSummaryClosed => 'Closed';

  @override
  String get tasksEmptyChannel => 'No tasks in this channel.';

  @override
  String get tasksFilterAll => 'All';

  @override
  String get tasksSectionTodo => 'To Do';

  @override
  String get tasksSectionInProgress => 'In Progress';

  @override
  String get tasksSectionInReview => 'In Review';

  @override
  String get tasksSectionDone => 'Done';

  @override
  String get tasksSectionClosed => 'Closed';

  @override
  String get tasksActionsTooltip => 'Task actions';

  @override
  String get tasksSwipeDone => 'Done';

  @override
  String get tasksActionMarkDone => 'Mark Done';

  @override
  String get tasksActionClose => 'Close Task';

  @override
  String get tasksActionStart => 'Start';

  @override
  String get tasksActionMoveToReview => 'Move to Review';

  @override
  String get tasksActionReopen => 'Reopen';

  @override
  String get tasksActionRevertInProgress => 'Revert to In Progress';

  @override
  String get tasksActionRevertTodo => 'Revert to To Do';

  @override
  String get tasksActionClaim => 'Claim';

  @override
  String get tasksActionUnclaim => 'Unclaim';

  @override
  String get tasksActionDelete => 'Delete';

  @override
  String get tasksRetryButton => 'Retry';

  @override
  String get tasksCreateTitle => 'Create Task';

  @override
  String get tasksCreateChannelLabel => 'Channel';

  @override
  String get tasksCreateTitleLabel => 'Title';

  @override
  String get tasksCreateCancel => 'Cancel';

  @override
  String get tasksCreateConfirm => 'Create';

  @override
  String get tasksAccessibilityTodo => 'To Do';

  @override
  String get tasksAccessibilityInProgress => 'In Progress';

  @override
  String get tasksAccessibilityInReview => 'In Review';

  @override
  String get tasksAccessibilityDone => 'Done';

  @override
  String get tasksAccessibilityClosed => 'Cancelled';

  @override
  String get screenshotAnnotateNoCapture => 'No screenshot captured';

  @override
  String get screenshotAnnotateDiscardTooltip => 'Discard';

  @override
  String get screenshotAnnotateTitle => 'Annotate Screenshot';

  @override
  String get screenshotAnnotateSaveTooltip => 'Save to device';

  @override
  String get screenshotAnnotateShareTooltip => 'Share';

  @override
  String get screenshotAnnotateAddTextTitle => 'Add Text';

  @override
  String get screenshotAnnotateTextHint => 'Enter text...';

  @override
  String get screenshotAnnotateCancel => 'Cancel';

  @override
  String get screenshotAnnotateAddButton => 'Add';

  @override
  String get screenshotAnnotateExportFailed => 'Failed to export screenshot';

  @override
  String screenshotAnnotateExportError(String error) {
    return 'Export failed: $error';
  }

  @override
  String screenshotAnnotateSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get screenshotAnnotateShareSubject => 'Screenshot';

  @override
  String get dateSeparatorToday => 'Today';

  @override
  String get dateSeparatorYesterday => 'Yesterday';

  @override
  String get conversationComposerHint => 'Write a message';

  @override
  String get conversationComposerAttachPhotoVideo => 'Photo & Video';

  @override
  String get conversationComposerAttachCamera => 'Camera';

  @override
  String get conversationComposerAttachFile => 'File';

  @override
  String get conversationComposerSendFailedFallback =>
      'Failed to send message.';

  @override
  String get conversationComposerAttachTooltip => 'Attach file';

  @override
  String get conversationComposerFormattingTooltip => 'Formatting';

  @override
  String get conversationComposerEmojiTooltip => 'Emoji';

  @override
  String get conversationComposerCameraUnavailable =>
      'Camera unavailable. Please check permissions.';

  @override
  String get conversationContextEditMessage => 'Edit message';

  @override
  String get conversationContextReply => 'Reply';

  @override
  String get conversationContextSelect => 'Select';

  @override
  String get conversationContextReact => 'React';

  @override
  String get conversationContextTranslate => 'Translate';

  @override
  String get conversationContextCopyText => 'Copy text';

  @override
  String get conversationContextForward => 'Forward';

  @override
  String get conversationContextSaveMessage => 'Save message';

  @override
  String get conversationContextUnsaveMessage => 'Unsave message';

  @override
  String get conversationContextPinMessage => 'Pin message';

  @override
  String get conversationContextUnpinMessage => 'Unpin message';

  @override
  String get conversationContextReplyInThread => 'Reply in thread';

  @override
  String get conversationContextCreateTask => 'Create task';

  @override
  String get conversationContextDeleteMessage => 'Delete message';

  @override
  String get conversationSelectionCancel => 'Cancel';

  @override
  String get conversationSelectionSave => 'Save';

  @override
  String get conversationSelectionExportAsImage => 'Export as image';

  @override
  String get conversationSelectionDelete => 'Delete';

  @override
  String conversationSelectionSelected(int count) {
    return '$count selected';
  }

  @override
  String conversationSelectionBatchSucceeded(int count, String action) {
    return '$count $action.';
  }

  @override
  String conversationSelectionBatchFailed(String action, int count) {
    return 'Failed to $action $count message(s).';
  }

  @override
  String conversationSelectionBatchPartial(
      int succeeded, String action, int failed) {
    return '$succeeded $action, $failed failed.';
  }

  @override
  String get conversationSelectionActionSaveVerb => 'save';

  @override
  String get conversationSelectionActionSaved => 'saved';

  @override
  String get conversationSelectionActionDeleteVerb => 'delete';

  @override
  String get conversationSelectionActionDeleted => 'deleted';

  @override
  String get conversationEditDialogTitle => 'Edit message';

  @override
  String get conversationEditDialogCancel => 'Cancel';

  @override
  String get conversationEditDialogSave => 'Save';

  @override
  String get conversationEditSuccess => 'Message edited.';

  @override
  String get conversationEditFailedFallback => 'Failed to edit message.';

  @override
  String get conversationMessageDeletedPlaceholder => '[Message deleted]';

  @override
  String get conversationReactionFailedFallback => 'Failed to add reaction.';

  @override
  String get conversationReactWithEmojiTitle => 'React with emoji';

  @override
  String conversationReactWithEmojiSemantics(String emoji) {
    return 'React with $emoji';
  }

  @override
  String get conversationReactionUpdateFailedFallback =>
      'Failed to update reaction.';

  @override
  String get conversationDeleteDialogTitle => 'Delete message?';

  @override
  String get conversationDeleteDialogContent =>
      'This message will be permanently deleted.';

  @override
  String get conversationDeleteDialogCancel => 'Cancel';

  @override
  String get conversationDeleteDialogConfirm => 'Delete';

  @override
  String get conversationDeleteSuccess => 'Message deleted.';

  @override
  String get conversationDeleteFailedFallback => 'Failed to delete message.';

  @override
  String get conversationOpenLinkTitle => 'Open Link';

  @override
  String conversationOpenLinkContent(String url) {
    return 'Open $url?';
  }

  @override
  String get conversationOpenLinkCancel => 'Cancel';

  @override
  String get conversationOpenLinkConfirm => 'Open';

  @override
  String get conversationMessageActionsSemantics => 'Message actions';

  @override
  String get conversationShowMessageMenuSemantics => 'Show message menu';

  @override
  String get conversationReplySemantics => 'Reply';

  @override
  String get channelStopAllAgents => 'Stop All Agents';

  @override
  String get channelResumeAllAgents => 'Resume All Agents';

  @override
  String get channelStopAllAgentsTitle => 'Stop all agents';

  @override
  String get channelStopAllAgentsMessage =>
      'Stop all agents in this channel? They will not respond until resumed.';

  @override
  String get channelStopAllAgentsConfirm => 'Stop All';

  @override
  String get channelStopAllAgentsSuccess => 'All agents stopped.';

  @override
  String get channelStopAllAgentsFailed => 'Failed to stop agents.';

  @override
  String get channelResumeAllAgentsSuccess => 'All agents resumed.';

  @override
  String get channelResumeAllAgentsFailed => 'Failed to resume agents.';

  @override
  String get cancel => 'Cancel';

  @override
  String get errorNetwork =>
      'Network error. Please check your connection and try again.';

  @override
  String get errorTimeout => 'Request timed out. Please try again.';

  @override
  String get errorUnauthorized => 'Session expired. Please sign in again.';

  @override
  String get errorForbidden =>
      'You don\'t have permission to perform this action.';

  @override
  String get errorNotFound => 'The requested resource was not found.';

  @override
  String get errorConflict =>
      'A conflict occurred. Please refresh and try again.';

  @override
  String get errorValidation => 'Invalid input. Please check and try again.';

  @override
  String get errorRateLimit =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String get errorCancelled => 'Request was cancelled.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get pendingNewMessages => 'New messages';

  @override
  String get pendingSending => 'Sending...';

  @override
  String get pendingQueued => 'Queued — waiting for connection';

  @override
  String get pendingSent => 'Sent';

  @override
  String get pendingFailedToSend => 'Failed to send';

  @override
  String get pendingRetry => 'Retry';

  @override
  String get pendingDismiss => 'Dismiss';

  @override
  String get pendingEarlierHistoryLimited => 'Earlier history is limited.';

  @override
  String get composerSendTooltip => 'Send';

  @override
  String get composerVoiceMessageTooltip => 'Voice message';

  @override
  String get composerFileTooLarge => 'File too large. Maximum size: 50 MB';

  @override
  String get messageSenderYou => 'You';

  @override
  String get channelActionMoveUp => 'Move up';

  @override
  String get channelActionMoveDown => 'Move down';

  @override
  String get channelActionPin => 'Pin channel';

  @override
  String get channelActionUnpin => 'Unpin channel';

  @override
  String get channelActionMarkUnread => 'Mark as Unread';

  @override
  String get channelActionEdit => 'Edit channel';

  @override
  String get channelActionLeave => 'Leave channel';

  @override
  String get channelActionDelete => 'Delete channel';

  @override
  String get channelsSortAlphabetical => 'Sort A-Z';

  @override
  String get channelsSortRecent => 'Sort by recent';

  @override
  String get channelsMarkAllRead => 'Mark all read';

  @override
  String get channelsClearSearch => 'Clear search';

  @override
  String get channelsMarkedUnread => 'Marked as unread';

  @override
  String get channelsCreateTitle => 'New Channel';

  @override
  String get channelsCreateSectionName => 'CHANNEL NAME';

  @override
  String get channelsCreateNameHint => 'channel-name';

  @override
  String get channelsCreateSectionDescription => 'DESCRIPTION (OPTIONAL)';

  @override
  String get channelsCreateDescriptionHint => 'What is this channel about?';

  @override
  String get channelsCreateSectionVisibility => 'VISIBILITY';

  @override
  String get channelsCreateSubmitting => 'Creating...';

  @override
  String get channelsCreateSubmit => 'Create Channel';

  @override
  String get channelsCreateNoServer => 'No active server selected.';

  @override
  String get channelsCreateVisibilityPublic => 'Public';

  @override
  String get channelsCreateVisibilityPublicSub => 'Visible to all';

  @override
  String get channelsCreateVisibilityPrivate => 'Private';

  @override
  String get channelsCreateVisibilityPrivateSub => 'Invite only';

  @override
  String get channelsMembersTitle => 'Channel Members';

  @override
  String get channelsMembersRetry => 'Retry';

  @override
  String get channelsMembersEmpty => 'No members in this channel.';

  @override
  String get channelsMembersTypeAgent => 'Agent';

  @override
  String get channelsMembersTypeHuman => 'Human';

  @override
  String get channelsMembersMessageTooltip => 'Message';

  @override
  String get channelsMembersRemoveTitle => 'Remove Member?';

  @override
  String channelsMembersRemoveMessage(String name) {
    return 'Remove $name from this channel?';
  }

  @override
  String get channelsMembersRemoveCancel => 'Cancel';

  @override
  String get channelsMembersRemoveConfirm => 'Remove';

  @override
  String get channelsAddMemberTitle => 'Add Member';

  @override
  String get channelsAddMemberTabHumans => 'Humans';

  @override
  String get channelsAddMemberTabAgents => 'Agents';

  @override
  String get channelsAddMemberClose => 'Close';

  @override
  String get channelsAddMemberNoHumans => 'No more humans to add.';

  @override
  String get channelsAddMemberNoAgents => 'No more agents to add.';

  @override
  String get channelsDialogCreateTitle => 'Create channel';

  @override
  String get channelsDialogCreateNameLabel => 'Channel name';

  @override
  String get channelsDialogCreateCancel => 'Cancel';

  @override
  String get channelsDialogCreateSubmitting => 'Creating...';

  @override
  String get channelsDialogCreateSubmit => 'Create';

  @override
  String get channelsDialogEditTitle => 'Edit channel';

  @override
  String get channelsDialogEditNameLabel => 'Channel name';

  @override
  String get channelsDialogEditCancel => 'Cancel';

  @override
  String get channelsDialogEditSubmitting => 'Saving...';

  @override
  String get channelsDialogEditSubmit => 'Save';

  @override
  String get channelsDialogConfirmCancel => 'Cancel';

  @override
  String get channelsDialogConfirmWorking => 'Working...';

  @override
  String get serversInviteTitle => 'Join Workspace';

  @override
  String get serversInviteJoining => 'Joining workspace...';

  @override
  String get serversInviteFailedFallback => 'Failed to join workspace.';

  @override
  String get serversInviteRetry => 'Retry';

  @override
  String get serversInviteGoHome => 'Go home';

  @override
  String get serversInviteDescription =>
      'You have been invited to join a workspace.';

  @override
  String get serversInviteAccept => 'Join workspace';

  @override
  String get serversInviteCancel => 'Cancel';

  @override
  String serversInviteSuccessNamed(String name) {
    return 'Joined $name!';
  }

  @override
  String get serversInviteSuccessGeneric => 'Joined workspace!';

  @override
  String get serversInviteContinue => 'Continue';

  @override
  String get serversDialogCreateTitle => 'Create workspace';

  @override
  String get serversDialogCreateNameLabel => 'Workspace name';

  @override
  String get serversDialogCreateCancel => 'Cancel';

  @override
  String get serversDialogCreateSubmit => 'Create';

  @override
  String get serversDialogRenameTitle => 'Rename workspace';

  @override
  String get serversDialogRenameNameLabel => 'Workspace name';

  @override
  String get serversDialogRenameCancel => 'Cancel';

  @override
  String get serversDialogRenameSubmit => 'Save';

  @override
  String get serversDialogJoinTitle => 'Join workspace';

  @override
  String get serversDialogJoinLabel => 'Invite code or link';

  @override
  String get serversDialogJoinHint => 'https://slock.ai/invite/token-123';

  @override
  String get serversDialogJoinCancel => 'Cancel';

  @override
  String get serversDialogJoinSubmit => 'Join';

  @override
  String get serversDialogConfirmCancel => 'Cancel';

  @override
  String get serversSwitcherTitle => 'Switch workspace';

  @override
  String get serversSwitcherCreating => 'Creating...';

  @override
  String get serversSwitcherCreateAction => 'Create workspace';

  @override
  String get serversSwitcherJoining => 'Joining...';

  @override
  String get serversSwitcherJoinAction => 'Join workspace';

  @override
  String get serversSwitcherEmpty => 'No workspaces available.';

  @override
  String get serversSwitcherSettings => 'Workspace Settings';

  @override
  String get serversSwitcherCreatedSnackbar => 'Workspace created.';

  @override
  String get serversSwitcherJoinedSnackbar => 'Workspace joined.';

  @override
  String get serversSwitcherDeleteTitle => 'Delete workspace?';

  @override
  String serversSwitcherDeleteMessage(String name) {
    return 'Delete $name? This permanently removes the workspace.';
  }

  @override
  String get serversSwitcherDeleteConfirm => 'Delete';

  @override
  String get serversSwitcherDeletedSnackbar => 'Workspace deleted.';

  @override
  String get serversSwitcherLeaveTitle => 'Leave workspace?';

  @override
  String serversSwitcherLeaveMessage(String name) {
    return 'Leave $name? You can rejoin later with a new invite.';
  }

  @override
  String get serversSwitcherLeaveConfirm => 'Leave';

  @override
  String get serversSwitcherLeftSnackbar => 'Workspace left.';

  @override
  String get serversSwitcherRenamedSnackbar => 'Workspace renamed.';

  @override
  String get serversSwitcherRowRename => 'Rename';

  @override
  String get serversSwitcherRowDelete => 'Delete workspace';

  @override
  String get serversSwitcherRowLeave => 'Leave workspace';

  @override
  String get serversSwitcherRetry => 'Retry';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Slock';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingFinish => 'Finish';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingSetupTitle => 'Set up your workspace';

  @override
  String get onboardingSetupBody =>
      'Slock is ready. Take a minute to configure notifications and your profile before jumping in.';

  @override
  String get onboardingNotificationsTitle => 'Stay in the loop';

  @override
  String get onboardingNotificationsBody =>
      'Enable notifications so mentions, replies, and tasks reach you quickly.';

  @override
  String get onboardingNotificationsButton => 'Enable notifications';

  @override
  String get onboardingProfileTitle => 'Complete your profile';

  @override
  String get onboardingProfileBody =>
      'Add your display name, bio, or avatar so teammates can recognize you.';

  @override
  String get onboardingProfileButton => 'Edit profile';

  @override
  String get agentsEmptyTitle => 'No agents yet.';

  @override
  String get agentsSelectServerFirst => 'Select a server first.';

  @override
  String get agentsCreated => 'Agent created.';

  @override
  String get agentsUpdated => 'Agent updated.';

  @override
  String get agentsDeleted => 'Agent deleted.';

  @override
  String get agentsResetSuccess => 'Agent reset.';

  @override
  String get agentsDeleteTitle => 'Delete Agent?';

  @override
  String agentsDeleteMessage(String name) {
    return 'Delete $name? This removes the agent configuration from the workspace.';
  }

  @override
  String get agentsStopTitle => 'Stop Agent?';

  @override
  String agentsStopMessage(String name) {
    return 'Stop $name? The agent will finish its current action before stopping.';
  }

  @override
  String get agentsResetTitle => 'Reset Session?';

  @override
  String agentsResetMessage(String name) {
    return 'Reset $name? This clears the agent\'s conversation history.';
  }

  @override
  String agentsSummary(int active, int stopped) {
    return '$active active / $stopped stopped';
  }

  @override
  String get agentsActionStart => 'Start';

  @override
  String get agentsActionStop => 'Stop';

  @override
  String get agentsActionReset => 'Reset';

  @override
  String get agentsActionResetSession => 'Reset Session';

  @override
  String get agentsActionMessage => 'Message';

  @override
  String get agentsActionDelete => 'Delete';

  @override
  String get agentsActionCancel => 'Cancel';

  @override
  String get agentsAppBarTitle => 'Agent';

  @override
  String get agentsFailedToLoad => 'Failed to load agents.';

  @override
  String get agentsNotFound => 'Agent not found.';

  @override
  String get agentsActivityLogTitle => 'Activity Log';

  @override
  String get agentsActivityLogEmpty => 'No activity log entries.';

  @override
  String get agentsConfigMachine => 'Machine';

  @override
  String get agentsConfigRuntime => 'Runtime';

  @override
  String get agentsConfigModel => 'Model';

  @override
  String get agentsConfigReasoning => 'Reasoning';

  @override
  String get agentsEnvVarsTitle => 'Environment Variables';

  @override
  String get agentsEnvVarsEmpty => 'No environment variables';

  @override
  String get agentsRetry => 'Retry';

  @override
  String get agentsActivityOnline => 'Online';

  @override
  String get agentsActivityThinking => 'Thinking...';

  @override
  String get agentsActivityWorking => 'Working...';

  @override
  String get agentsActivityError => 'Error';

  @override
  String agentsActivityErrorDetail(String detail) {
    return 'Error: $detail';
  }

  @override
  String get agentsActivityOffline => 'Offline';

  @override
  String get agentsFormEditTitle => 'Edit Agent';

  @override
  String get agentsFormCreateTitle => 'Create Agent';

  @override
  String get agentsFormNameRequired => 'Name is required.';

  @override
  String get agentsFormMachineRequired => 'Machine is required.';

  @override
  String get agentsFormRuntimeRequired => 'Runtime is required.';

  @override
  String get agentsFormModelRequired => 'Model is required.';

  @override
  String get agentsFormNoMachines => 'No machines available for this server.';

  @override
  String get agentsFormLabelMachine => 'Machine';

  @override
  String get agentsFormLabelName => 'Name';

  @override
  String get agentsFormLabelDescription => 'Description';

  @override
  String get agentsFormLabelRuntime => 'Runtime';

  @override
  String get agentsFormLabelModel => 'Model';

  @override
  String get agentsFormLabelReasoningEffort => 'Reasoning Effort';

  @override
  String get agentsFormSave => 'Save';

  @override
  String get agentsFormCreate => 'Create';

  @override
  String get agentsFormCancel => 'Cancel';

  @override
  String get agentsFormRetry => 'Retry';

  @override
  String get agentsReasoningLow => 'Low';

  @override
  String get agentsReasoningMedium => 'Medium';

  @override
  String get agentsReasoningHigh => 'High';

  @override
  String get agentsReasoningExtraHigh => 'Extra High';

  @override
  String get agentsFormConfiguredDefault => 'Configured Default';

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get profileEditSave => 'Save';

  @override
  String get profileEditSnackbarSaved => 'Profile updated.';

  @override
  String get profileEditSnackbarAvatarSavedProfileFailed =>
      'Avatar updated. Profile save failed — tap Save to retry.';

  @override
  String get profileEditNewAvatarSelected => 'New avatar selected';

  @override
  String get profileEditChangeAvatar => 'Change avatar';

  @override
  String get profileEditSectionDetails => 'Profile details';

  @override
  String get profileEditDisplayNameLabel => 'Display name';

  @override
  String get profileEditDisplayNameRequired => 'Display name is required.';

  @override
  String get profileEditBioLabel => 'Bio / status';

  @override
  String get profileTitleSelf => 'My Profile';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileRetry => 'Retry';

  @override
  String get profileNotAvailable => 'Profile not available.';

  @override
  String get profileLabelUserId => 'User ID';

  @override
  String get profileLabelUsername => 'Username';

  @override
  String get profileLabelEmail => 'Email';

  @override
  String get profileLabelRole => 'Role';

  @override
  String get profileLabelMemberSince => 'Member since';

  @override
  String get profileEditComingSoon => 'Profile editing coming soon';

  @override
  String get profileEditButton => 'Edit Profile';

  @override
  String get profileThisIsYou => 'This is you';

  @override
  String get profileMessageButton => 'Message';

  @override
  String profileDateFormat(String month, int day, int year) {
    return '$month $day, $year';
  }

  @override
  String get profileMonthJan => 'Jan';

  @override
  String get profileMonthFeb => 'Feb';

  @override
  String get profileMonthMar => 'Mar';

  @override
  String get profileMonthApr => 'Apr';

  @override
  String get profileMonthMay => 'May';

  @override
  String get profileMonthJun => 'Jun';

  @override
  String get profileMonthJul => 'Jul';

  @override
  String get profileMonthAug => 'Aug';

  @override
  String get profileMonthSep => 'Sep';

  @override
  String get profileMonthOct => 'Oct';

  @override
  String get profileMonthNov => 'Nov';

  @override
  String get profileMonthDec => 'Dec';

  @override
  String get settingsEditProfileTitle => 'Edit profile';

  @override
  String get settingsEditProfileSubtitle =>
      'Update your display name, bio, and avatar';

  @override
  String get inboxTitle => 'Inbox';

  @override
  String get inboxMarkAllReadTooltip => 'Mark all read';

  @override
  String get inboxLoadFailed => 'Failed to load inbox';

  @override
  String get inboxRetry => 'Retry';

  @override
  String get inboxEmptyTitle => 'All caught up!';

  @override
  String get inboxEmptySubtitle => 'No messages in your inbox';

  @override
  String get inboxActionMarkRead => 'Mark Read';

  @override
  String get inboxSwipeLabelRead => 'Read';

  @override
  String get inboxFilterUnread => 'Unread';

  @override
  String get inboxFilterMentions => '@Mentions';

  @override
  String get inboxFilterDms => 'DMs';

  @override
  String get inboxFilterAll => 'All';

  @override
  String get inboxMentionBadge => '@you';

  @override
  String get inboxTimeNow => 'now';

  @override
  String inboxTimeMinutes(int count) {
    return '${count}m';
  }

  @override
  String inboxTimeHours(int count) {
    return '${count}h';
  }

  @override
  String inboxTimeDays(int count) {
    return '${count}d';
  }

  @override
  String get inboxUnreadCountOverflow => '99+';

  @override
  String get settingsAppearanceTitle => 'Appearance';

  @override
  String get settingsAppearanceThemeSection => 'Theme';

  @override
  String get settingsThemeSystemTitle => 'Follow System';

  @override
  String get settingsThemeSystemDescription => 'Use your device theme setting.';

  @override
  String get settingsThemeLightTitle => 'Light';

  @override
  String get settingsThemeLightDescription => 'Always use the light theme.';

  @override
  String get settingsThemeDarkTitle => 'Dark';

  @override
  String get settingsThemeDarkDescription => 'Always use the dark theme.';

  @override
  String get settingsDiagnosticsPageTitle => 'Diagnostics';

  @override
  String settingsDiagnosticsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'entries',
      one: 'entry',
    );
    return '$count $_temp0';
  }

  @override
  String get settingsDiagnosticsFilterAll => 'All';

  @override
  String get settingsDiagnosticsFilterInfo => 'Info';

  @override
  String get settingsDiagnosticsFilterWarning => 'Warning';

  @override
  String get settingsDiagnosticsFilterError => 'Error';

  @override
  String get settingsDiagnosticsEmpty => 'No diagnostic entries';

  @override
  String get settingsDiagnosticsWorkerLoading => 'Background worker: loading…';

  @override
  String get settingsDiagnosticsWorkerUnavailable =>
      'Background worker diagnostics unavailable';

  @override
  String get settingsDiagnosticsWorkerNotRunning =>
      'Background worker: not running';

  @override
  String get settingsDiagnosticsWorkerTitle => 'Background worker';

  @override
  String get settingsTranslationPageTitle => 'Translation';

  @override
  String get settingsTranslationNoActiveWorkspace =>
      'No active workspace. Translation settings are workspace-level.';

  @override
  String get settingsTranslationRetry => 'Retry';

  @override
  String get settingsTranslationSectionMode => 'Translation Mode';

  @override
  String get settingsTranslationSectionLanguage => 'Preferred Language';

  @override
  String get settingsTranslationModeAutoTitle => 'Automatic';

  @override
  String get settingsTranslationModeManualTitle => 'Manual';

  @override
  String get settingsTranslationModeOffTitle => 'Off';

  @override
  String get settingsTranslationModeAutoDescription =>
      'Automatically translate messages when entering a conversation';

  @override
  String get settingsTranslationModeManualDescription =>
      'Translate only when you tap the translate button';

  @override
  String get settingsTranslationModeOffDescription => 'Translation is disabled';
}
