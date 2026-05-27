import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Slock'**
  String get appTitle;

  /// No description provided for @splashTitle.
  ///
  /// In en, this message translates to:
  /// **'Slock'**
  String get splashTitle;

  /// No description provided for @splashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing your workspace...'**
  String get splashSubtitle;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginSubmitLabel.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginSubmitLabel;

  /// No description provided for @loginCreateAccountCta.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get loginCreateAccountCta;

  /// No description provided for @loginForgotPasswordCta.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPasswordCta;

  /// No description provided for @loginEmailRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get loginEmailRequiredError;

  /// No description provided for @loginEmailInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get loginEmailInvalidError;

  /// No description provided for @loginPasswordRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get loginPasswordRequiredError;

  /// No description provided for @loginFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailedFallback;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @registerDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get registerDisplayNameLabel;

  /// No description provided for @registerEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get registerEmailLabel;

  /// No description provided for @registerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get registerPasswordLabel;

  /// No description provided for @registerSubmitLabel.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerSubmitLabel;

  /// No description provided for @registerAlreadyHaveAccountCta.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get registerAlreadyHaveAccountCta;

  /// No description provided for @registerDisplayNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Display name is required.'**
  String get registerDisplayNameRequiredError;

  /// No description provided for @registerEmailRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get registerEmailRequiredError;

  /// No description provided for @registerEmailInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get registerEmailInvalidError;

  /// No description provided for @registerPasswordTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get registerPasswordTooShortError;

  /// No description provided for @registerFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registerFailedFallback;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get forgotPasswordSuccessTitle;

  /// No description provided for @forgotPasswordSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'If that email is registered, a reset link has been sent. Check your inbox.'**
  String get forgotPasswordSuccessMessage;

  /// No description provided for @forgotPasswordEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get forgotPasswordEmailLabel;

  /// No description provided for @forgotPasswordSubmitLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordSubmitLabel;

  /// No description provided for @forgotPasswordBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get forgotPasswordBackToLogin;

  /// No description provided for @forgotPasswordEmailRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get forgotPasswordEmailRequiredError;

  /// No description provided for @forgotPasswordEmailInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get forgotPasswordEmailInvalidError;

  /// No description provided for @forgotPasswordFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email. Please try again.'**
  String get forgotPasswordFailedFallback;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Password reset complete. You can now sign in with your new password.'**
  String get resetPasswordCompletedMessage;

  /// No description provided for @resetPasswordNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetPasswordNewPasswordLabel;

  /// No description provided for @resetPasswordConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get resetPasswordConfirmPasswordLabel;

  /// No description provided for @resetPasswordSubmitLabel.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get resetPasswordSubmitLabel;

  /// No description provided for @resetPasswordBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get resetPasswordBackToLogin;

  /// No description provided for @resetPasswordLinkInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Reset link is missing or invalid.'**
  String get resetPasswordLinkInvalidError;

  /// No description provided for @resetPasswordTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get resetPasswordTooShortError;

  /// No description provided for @resetPasswordMismatchError.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get resetPasswordMismatchError;

  /// No description provided for @resetPasswordFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Password reset failed. The link may be expired.'**
  String get resetPasswordFailedFallback;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailInstructions.
  ///
  /// In en, this message translates to:
  /// **'Verify your email to continue.'**
  String get verifyEmailInstructions;

  /// No description provided for @verifyEmailResentMessage.
  ///
  /// In en, this message translates to:
  /// **'Verification email resent. Check your inbox.'**
  String get verifyEmailResentMessage;

  /// No description provided for @verifyEmailResendButton.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get verifyEmailResendButton;

  /// No description provided for @verifyEmailTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification token'**
  String get verifyEmailTokenLabel;

  /// No description provided for @verifyEmailSubmitLabel.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyEmailSubmitLabel;

  /// No description provided for @verifyEmailSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Email verified. You can continue to the app.'**
  String get verifyEmailSuccessMessage;

  /// No description provided for @verifyEmailContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue to Slock'**
  String get verifyEmailContinueButton;

  /// No description provided for @verifyEmailSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get verifyEmailSignOut;

  /// No description provided for @verifyEmailBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get verifyEmailBackToLogin;

  /// No description provided for @verifyEmailTokenRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter a verification token.'**
  String get verifyEmailTokenRequiredError;

  /// No description provided for @verifyEmailFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. The link may be expired.'**
  String get verifyEmailFailedFallback;

  /// No description provided for @verifyEmailResendFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend verification email.'**
  String get verifyEmailResendFailedFallback;

  /// No description provided for @navWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navWorkspace;

  /// No description provided for @navChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get navChannels;

  /// No description provided for @navDms.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navDms;

  /// No description provided for @navAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get navAgents;

  /// No description provided for @agentsNewTooltip.
  ///
  /// In en, this message translates to:
  /// **'New agent'**
  String get agentsNewTooltip;

  /// No description provided for @agentsNoMachineAssigned.
  ///
  /// In en, this message translates to:
  /// **'No Machine Assigned'**
  String get agentsNoMachineAssigned;

  /// No description provided for @releaseNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Release Notes'**
  String get releaseNotesTitle;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @homeWorkspaceConsole.
  ///
  /// In en, this message translates to:
  /// **'Workspace Console'**
  String get homeWorkspaceConsole;

  /// No description provided for @homeConsoleActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get homeConsoleActivityTitle;

  /// No description provided for @homeConsoleActivityDescription.
  ///
  /// In en, this message translates to:
  /// **'Saved context, threads, tasks, and search.'**
  String get homeConsoleActivityDescription;

  /// No description provided for @homeConsoleSavedMessages.
  ///
  /// In en, this message translates to:
  /// **'Saved Messages'**
  String get homeConsoleSavedMessages;

  /// No description provided for @homeConsoleSavedMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Return to bookmarked updates and references.'**
  String get homeConsoleSavedMessagesDescription;

  /// No description provided for @homeConsoleThreads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get homeConsoleThreads;

  /// No description provided for @homeConsoleThreadsDescription.
  ///
  /// In en, this message translates to:
  /// **'Review active thread work across the workspace.'**
  String get homeConsoleThreadsDescription;

  /// No description provided for @homeConsoleTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get homeConsoleTasks;

  /// No description provided for @homeConsoleTasksDescription.
  ///
  /// In en, this message translates to:
  /// **'See task queues and execution status.'**
  String get homeConsoleTasksDescription;

  /// No description provided for @homeConsoleSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeConsoleSearch;

  /// No description provided for @homeConsoleSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Find channels, messages, and workspace history.'**
  String get homeConsoleSearchDescription;

  /// No description provided for @homeConsoleOperationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get homeConsoleOperationsTitle;

  /// No description provided for @homeConsoleOperationsDescription.
  ///
  /// In en, this message translates to:
  /// **'People, infrastructure, billing, and settings.'**
  String get homeConsoleOperationsDescription;

  /// No description provided for @homeConsoleMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get homeConsoleMembers;

  /// No description provided for @homeConsoleMembersDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage workspace roles and invitations.'**
  String get homeConsoleMembersDescription;

  /// No description provided for @homeConsoleAgentControl.
  ///
  /// In en, this message translates to:
  /// **'Agent Control'**
  String get homeConsoleAgentControl;

  /// No description provided for @homeConsoleAgentControlDescription.
  ///
  /// In en, this message translates to:
  /// **'Inspect agent activity and assignments.'**
  String get homeConsoleAgentControlDescription;

  /// No description provided for @homeConsoleMachines.
  ///
  /// In en, this message translates to:
  /// **'Machines'**
  String get homeConsoleMachines;

  /// No description provided for @homeConsoleMachinesDescription.
  ///
  /// In en, this message translates to:
  /// **'Check workspace runtime capacity and hosts.'**
  String get homeConsoleMachinesDescription;

  /// No description provided for @homeConsoleBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get homeConsoleBilling;

  /// No description provided for @homeConsoleBillingDescription.
  ///
  /// In en, this message translates to:
  /// **'Review plan controls and billing management.'**
  String get homeConsoleBillingDescription;

  /// No description provided for @homeConsoleWorkspaceSettings.
  ///
  /// In en, this message translates to:
  /// **'Workspace Settings'**
  String get homeConsoleWorkspaceSettings;

  /// No description provided for @homeConsoleWorkspaceSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure workspace-level defaults and access.'**
  String get homeConsoleWorkspaceSettingsDescription;

  /// No description provided for @homeCardAgents.
  ///
  /// In en, this message translates to:
  /// **'AGENTS'**
  String get homeCardAgents;

  /// No description provided for @homeCardAgentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'agents in workspace'**
  String get homeCardAgentsSubtitle;

  /// No description provided for @homeCardAgentsOnline.
  ///
  /// In en, this message translates to:
  /// **'{count} online'**
  String homeCardAgentsOnline(int count);

  /// No description provided for @homeCardAgentsError.
  ///
  /// In en, this message translates to:
  /// **'{count} error'**
  String homeCardAgentsError(int count);

  /// No description provided for @homeCardAgentsStopped.
  ///
  /// In en, this message translates to:
  /// **'{count} stopped'**
  String homeCardAgentsStopped(int count);

  /// No description provided for @homeCardAgentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'All agents offline'**
  String get homeCardAgentsEmpty;

  /// No description provided for @homeCardTasks.
  ///
  /// In en, this message translates to:
  /// **'TASKS'**
  String get homeCardTasks;

  /// No description provided for @homeCardTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'total tasks'**
  String get homeCardTasksSubtitle;

  /// No description provided for @homeCardTasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active tasks'**
  String get homeCardTasksEmpty;

  /// No description provided for @homeCardTasksUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Tasks unavailable'**
  String get homeCardTasksUnavailable;

  /// No description provided for @homeCardTasksOverflow.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String homeCardTasksOverflow(int count);

  /// No description provided for @homeCardTasksInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get homeCardTasksInProgress;

  /// No description provided for @homeCardTasksTodo.
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get homeCardTasksTodo;

  /// No description provided for @homeCardTasksDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String homeCardTasksDurationMinutes(int count);

  /// No description provided for @homeCardTasksDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String homeCardTasksDurationHours(int hours, int minutes);

  /// No description provided for @homeCardTasksDurationHoursOnly.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String homeCardTasksDurationHoursOnly(int count);

  /// No description provided for @homeCardViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeCardViewAll;

  /// No description provided for @homeCardAgentActivityOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get homeCardAgentActivityOnline;

  /// No description provided for @homeCardAgentActivityThinking.
  ///
  /// In en, this message translates to:
  /// **'thinking'**
  String get homeCardAgentActivityThinking;

  /// No description provided for @homeCardAgentActivityWorking.
  ///
  /// In en, this message translates to:
  /// **'working'**
  String get homeCardAgentActivityWorking;

  /// No description provided for @homeCardAgentActivityError.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get homeCardAgentActivityError;

  /// No description provided for @homeCardAgentActivityOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get homeCardAgentActivityOffline;

  /// No description provided for @homeCardTimeAgoNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get homeCardTimeAgoNow;

  /// No description provided for @homeCardTimeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String homeCardTimeAgoMinutes(int count);

  /// No description provided for @homeCardTimeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String homeCardTimeAgoHours(int count);

  /// No description provided for @homeCardTimeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String homeCardTimeAgoDays(int count);

  /// No description provided for @homeCardUnread.
  ///
  /// In en, this message translates to:
  /// **'UNREAD'**
  String get homeCardUnread;

  /// No description provided for @homeCardUnreadEmpty.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get homeCardUnreadEmpty;

  /// No description provided for @homeCardUnreadOverflow.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String homeCardUnreadOverflow(int count);

  /// No description provided for @homeCardUnreadBadge.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String homeCardUnreadBadge(int count);

  /// No description provided for @homeCardUnreadMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get homeCardUnreadMarkAllRead;

  /// No description provided for @homeSectionPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get homeSectionPinned;

  /// No description provided for @homeSectionChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get homeSectionChannels;

  /// No description provided for @homeSectionDirectMessages.
  ///
  /// In en, this message translates to:
  /// **'Direct Messages'**
  String get homeSectionDirectMessages;

  /// No description provided for @homeSectionPinnedAgents.
  ///
  /// In en, this message translates to:
  /// **'Pinned Agents'**
  String get homeSectionPinnedAgents;

  /// No description provided for @homeSectionAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get homeSectionAgents;

  /// No description provided for @homeChannelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No channels yet.'**
  String get homeChannelsEmpty;

  /// No description provided for @homeDirectMessagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No direct messages yet.'**
  String get homeDirectMessagesEmpty;

  /// No description provided for @homeCreateChannelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create channel'**
  String get homeCreateChannelTooltip;

  /// No description provided for @homeNewMessageTooltip.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get homeNewMessageTooltip;

  /// No description provided for @homeHiddenConversationsCount.
  ///
  /// In en, this message translates to:
  /// **'Hidden conversations ({count})'**
  String homeHiddenConversationsCount(int count);

  /// No description provided for @homeHiddenConversationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hidden conversations'**
  String get homeHiddenConversationsTitle;

  /// No description provided for @homeUnhide.
  ///
  /// In en, this message translates to:
  /// **'Unhide'**
  String get homeUnhide;

  /// No description provided for @homePin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get homePin;

  /// No description provided for @homeUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get homeUnpin;

  /// No description provided for @homeNoServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a server to get started.'**
  String get homeNoServerMessage;

  /// No description provided for @homeSelectWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Select workspace'**
  String get homeSelectWorkspace;

  /// No description provided for @homeLoadFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Unable to load conversations.'**
  String get homeLoadFailedFallback;

  /// No description provided for @homeRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetry;

  /// No description provided for @channelsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channelsTabTitle;

  /// No description provided for @channelsTabPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Channel list will be available here soon.'**
  String get channelsTabPlaceholder;

  /// No description provided for @channelsTabSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search channels'**
  String get channelsTabSearchHint;

  /// No description provided for @channelsTabEmpty.
  ///
  /// In en, this message translates to:
  /// **'No channels yet.'**
  String get channelsTabEmpty;

  /// No description provided for @dmsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get dmsTabTitle;

  /// No description provided for @dmsTabHeadline.
  ///
  /// In en, this message translates to:
  /// **'Direct Messages'**
  String get dmsTabHeadline;

  /// No description provided for @dmsTabPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Direct messages will be available here soon.'**
  String get dmsTabPlaceholder;

  /// No description provided for @dmsTabSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get dmsTabSearchHint;

  /// No description provided for @dmsTabEmpty.
  ///
  /// In en, this message translates to:
  /// **'No direct messages yet.'**
  String get dmsTabEmpty;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @homeChannelCreated.
  ///
  /// In en, this message translates to:
  /// **'Channel created.'**
  String get homeChannelCreated;

  /// No description provided for @homeChannelCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create channel.'**
  String get homeChannelCreateFailed;

  /// No description provided for @homeChannelUpdated.
  ///
  /// In en, this message translates to:
  /// **'Channel updated.'**
  String get homeChannelUpdated;

  /// No description provided for @homeChannelUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update channel.'**
  String get homeChannelUpdateFailed;

  /// No description provided for @homeDeleteChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete channel'**
  String get homeDeleteChannelTitle;

  /// No description provided for @homeDeleteChannelMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This cannot be undone.'**
  String homeDeleteChannelMessage(String name);

  /// No description provided for @homeDeleteChannelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get homeDeleteChannelConfirm;

  /// No description provided for @homeChannelDeleted.
  ///
  /// In en, this message translates to:
  /// **'Channel deleted.'**
  String get homeChannelDeleted;

  /// No description provided for @homeChannelDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete channel.'**
  String get homeChannelDeleteFailed;

  /// No description provided for @homeLeaveChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave channel'**
  String get homeLeaveChannelTitle;

  /// No description provided for @homeLeaveChannelMessage.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}?'**
  String homeLeaveChannelMessage(String name);

  /// No description provided for @homeLeaveChannelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get homeLeaveChannelConfirm;

  /// No description provided for @homeChannelLeft.
  ///
  /// In en, this message translates to:
  /// **'Left channel.'**
  String get homeChannelLeft;

  /// No description provided for @homeChannelLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave channel.'**
  String get homeChannelLeaveFailed;

  /// No description provided for @baseUrlSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Configuration'**
  String get baseUrlSettingsTitle;

  /// No description provided for @baseUrlSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure custom API and WebSocket endpoints.'**
  String get baseUrlSettingsSubtitle;

  /// No description provided for @baseUrlApiLabel.
  ///
  /// In en, this message translates to:
  /// **'API Base URL'**
  String get baseUrlApiLabel;

  /// No description provided for @baseUrlApiHint.
  ///
  /// In en, this message translates to:
  /// **'https://api.example.com'**
  String get baseUrlApiHint;

  /// No description provided for @baseUrlRealtimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Realtime URL'**
  String get baseUrlRealtimeLabel;

  /// No description provided for @baseUrlRealtimeHint.
  ///
  /// In en, this message translates to:
  /// **'wss://realtime.example.com'**
  String get baseUrlRealtimeHint;

  /// No description provided for @baseUrlSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get baseUrlSave;

  /// No description provided for @baseUrlRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get baseUrlRestoreDefaults;

  /// No description provided for @baseUrlTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get baseUrlTestConnection;

  /// No description provided for @baseUrlTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get baseUrlTesting;

  /// No description provided for @baseUrlSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved. Restart the app to apply changes.'**
  String get baseUrlSaved;

  /// No description provided for @baseUrlRestored.
  ///
  /// In en, this message translates to:
  /// **'Defaults restored. Restart the app to apply changes.'**
  String get baseUrlRestored;

  /// No description provided for @baseUrlApiInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http:// or https:// URL.'**
  String get baseUrlApiInvalidError;

  /// No description provided for @baseUrlRealtimeInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid ws://, wss://, http://, or https:// URL.'**
  String get baseUrlRealtimeInvalidError;

  /// No description provided for @baseUrlResultReachable.
  ///
  /// In en, this message translates to:
  /// **'Reachable'**
  String get baseUrlResultReachable;

  /// No description provided for @baseUrlResultUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Reachable (unauthorized)'**
  String get baseUrlResultUnauthorized;

  /// No description provided for @baseUrlResultTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get baseUrlResultTimeout;

  /// No description provided for @baseUrlResultInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL'**
  String get baseUrlResultInvalid;

  /// No description provided for @baseUrlEmptyDefault.
  ///
  /// In en, this message translates to:
  /// **'Using build-time default'**
  String get baseUrlEmptyDefault;

  /// No description provided for @baseUrlRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart required to apply changes.'**
  String get baseUrlRestartRequired;

  /// No description provided for @baseUrlSettingsSettingsTile.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get baseUrlSettingsSettingsTile;

  /// No description provided for @baseUrlSettingsSettingsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Custom API and WebSocket endpoints.'**
  String get baseUrlSettingsSettingsTileSubtitle;

  /// No description provided for @attachmentOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get attachmentOpenInBrowser;

  /// No description provided for @attachmentUnableToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Unable to load image'**
  String get attachmentUnableToLoadImage;

  /// No description provided for @attachmentHtmlOpensInBrowser.
  ///
  /// In en, this message translates to:
  /// **'HTML • Opens in browser'**
  String get attachmentHtmlOpensInBrowser;

  /// No description provided for @refreshFailedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh. Showing cached data.'**
  String get refreshFailedSnackbar;

  /// No description provided for @refreshFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get refreshFailedRetry;

  /// No description provided for @workspaceSettingsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace settings unavailable'**
  String get workspaceSettingsUnavailableTitle;

  /// No description provided for @workspaceSettingsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not load workspace settings right now.'**
  String get workspaceSettingsUnavailableMessage;

  /// No description provided for @workspaceSettingsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Workspace not found.'**
  String get workspaceSettingsNotFound;

  /// No description provided for @workspaceSettingsRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get workspaceSettingsRoleLabel;

  /// No description provided for @workspaceSettingsRoleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get workspaceSettingsRoleUnknown;

  /// No description provided for @workspaceSettingsCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get workspaceSettingsCreatedLabel;

  /// No description provided for @workspaceSettingsManageSection.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get workspaceSettingsManageSection;

  /// No description provided for @workspaceSettingsActionsSection.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get workspaceSettingsActionsSection;

  /// No description provided for @workspaceSettingsRenameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename workspace'**
  String get workspaceSettingsRenameAction;

  /// No description provided for @workspaceSettingsDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace'**
  String get workspaceSettingsDeleteAction;

  /// No description provided for @workspaceSettingsLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave workspace'**
  String get workspaceSettingsLeaveAction;

  /// No description provided for @workspaceSettingsRenamedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Workspace renamed.'**
  String get workspaceSettingsRenamedSnackbar;

  /// No description provided for @workspaceSettingsRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename workspace.'**
  String get workspaceSettingsRenameFailed;

  /// No description provided for @workspaceSettingsDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace?'**
  String get workspaceSettingsDeleteDialogTitle;

  /// No description provided for @workspaceSettingsDeleteDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This permanently removes the workspace and all its data.'**
  String workspaceSettingsDeleteDialogMessage(String name);

  /// No description provided for @workspaceSettingsDeleteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get workspaceSettingsDeleteConfirmLabel;

  /// No description provided for @workspaceSettingsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete workspace.'**
  String get workspaceSettingsDeleteFailed;

  /// No description provided for @workspaceSettingsLeaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave workspace?'**
  String get workspaceSettingsLeaveDialogTitle;

  /// No description provided for @workspaceSettingsLeaveDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}? You can rejoin later with a new invite.'**
  String workspaceSettingsLeaveDialogMessage(String name);

  /// No description provided for @workspaceSettingsLeaveConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get workspaceSettingsLeaveConfirmLabel;

  /// No description provided for @workspaceSettingsLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave workspace.'**
  String get workspaceSettingsLeaveFailed;

  /// No description provided for @previewDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get previewDeleted;

  /// No description provided for @previewSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get previewSending;

  /// No description provided for @previewFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent, tap to retry'**
  String get previewFailed;

  /// No description provided for @previewSystem.
  ///
  /// In en, this message translates to:
  /// **'System message'**
  String get previewSystem;

  /// No description provided for @previewLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get previewLink;

  /// No description provided for @previewVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get previewVoice;

  /// No description provided for @previewImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get previewImage;

  /// No description provided for @previewVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get previewVideo;

  /// No description provided for @previewFallback.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get previewFallback;

  /// No description provided for @previewAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment: {name}'**
  String previewAttachment(String name);

  /// No description provided for @agentStatusThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get agentStatusThinking;

  /// No description provided for @agentStatusWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get agentStatusWorking;

  /// No description provided for @agentStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get agentStatusError;

  /// No description provided for @agentStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get agentStatusOnline;

  /// No description provided for @agentStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get agentStatusOffline;

  /// No description provided for @agentStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get agentStatusStopped;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsWorkspaceSection.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get settingsWorkspaceSection;

  /// No description provided for @settingsNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSection;

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceSection;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecuritySection;

  /// No description provided for @settingsMoreSection.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get settingsMoreSection;

  /// No description provided for @settingsDangerZoneSection.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settingsDangerZoneSection;

  /// No description provided for @settingsMyProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get settingsMyProfileTitle;

  /// No description provided for @settingsMyProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review your current account details.'**
  String get settingsMyProfileSubtitle;

  /// No description provided for @settingsMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get settingsMembersTitle;

  /// No description provided for @settingsMembersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and manage workspace members.'**
  String get settingsMembersSubtitle;

  /// No description provided for @settingsNotificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get settingsNotificationSettingsTitle;

  /// No description provided for @settingsThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeTitle;

  /// No description provided for @settingsTranslationTitle.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get settingsTranslationTitle;

  /// No description provided for @settingsTranslationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preferred language and translation mode.'**
  String get settingsTranslationSubtitle;

  /// No description provided for @settingsBiometricLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric Lock'**
  String get settingsBiometricLockTitle;

  /// No description provided for @settingsBiometricLockEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled — unlock with biometrics after inactivity'**
  String get settingsBiometricLockEnabled;

  /// No description provided for @settingsBiometricLockDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled — no biometric lock on app access'**
  String get settingsBiometricLockDisabled;

  /// No description provided for @settingsBillingTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get settingsBillingTitle;

  /// No description provided for @settingsBillingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review your current subscription summary.'**
  String get settingsBillingSubtitle;

  /// No description provided for @settingsReleaseNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Release Notes'**
  String get settingsReleaseNotesTitle;

  /// No description provided for @settingsReleaseNotesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See the latest packaged product updates.'**
  String get settingsReleaseNotesSubtitle;

  /// No description provided for @settingsDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnosticsTitle;

  /// No description provided for @settingsDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and export diagnostic logs.'**
  String get settingsDiagnosticsSubtitle;

  /// No description provided for @settingsLogOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get settingsLogOutTitle;

  /// No description provided for @settingsLogOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this device.'**
  String get settingsLogOutSubtitle;

  /// No description provided for @settingsLogOutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get settingsLogOutDialogTitle;

  /// No description provided for @settingsLogOutDialogContent.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out of this device.'**
  String get settingsLogOutDialogContent;

  /// No description provided for @settingsLogOutDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsLogOutDialogCancel;

  /// No description provided for @settingsLogOutDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOutDialogConfirm;

  /// No description provided for @settingsSignedInFallback.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get settingsSignedInFallback;

  /// No description provided for @settingsAccountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account details unavailable'**
  String get settingsAccountUnavailable;

  /// No description provided for @settingsNotificationGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get settingsNotificationGranted;

  /// No description provided for @settingsNotificationDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get settingsNotificationDenied;

  /// No description provided for @settingsNotificationProvisional.
  ///
  /// In en, this message translates to:
  /// **'Provisional'**
  String get settingsNotificationProvisional;

  /// No description provided for @settingsNotificationNotRequested.
  ///
  /// In en, this message translates to:
  /// **'Not requested'**
  String get settingsNotificationNotRequested;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsPermissionSection.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get notificationSettingsPermissionSection;

  /// No description provided for @notificationSettingsPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get notificationSettingsPushNotifications;

  /// No description provided for @notificationSettingsFilterSection.
  ///
  /// In en, this message translates to:
  /// **'Notification Filter'**
  String get notificationSettingsFilterSection;

  /// No description provided for @notificationSettingsDiagnosticsSection.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get notificationSettingsDiagnosticsSection;

  /// No description provided for @notificationSettingsDeviceToken.
  ///
  /// In en, this message translates to:
  /// **'Device Token'**
  String get notificationSettingsDeviceToken;

  /// No description provided for @notificationSettingsPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get notificationSettingsPlatform;

  /// No description provided for @notificationSettingsLastRegistration.
  ///
  /// In en, this message translates to:
  /// **'Last Registration'**
  String get notificationSettingsLastRegistration;

  /// No description provided for @notificationSettingsPermissionStatus.
  ///
  /// In en, this message translates to:
  /// **'Permission Status'**
  String get notificationSettingsPermissionStatus;

  /// No description provided for @notificationSettingsRecentEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent Events'**
  String get notificationSettingsRecentEvents;

  /// No description provided for @notificationSettingsNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No recent notification events.'**
  String get notificationSettingsNoEvents;

  /// No description provided for @notificationSettingsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notificationSettingsNotAvailable;

  /// No description provided for @notificationSettingsNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Not registered yet'**
  String get notificationSettingsNotRegistered;

  /// No description provided for @notificationSettingsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update notification settings.'**
  String get notificationSettingsUpdateFailed;

  /// No description provided for @notificationSettingsRefreshRegistration.
  ///
  /// In en, this message translates to:
  /// **'Refresh Device Registration'**
  String get notificationSettingsRefreshRegistration;

  /// No description provided for @notificationSettingsRetryAccess.
  ///
  /// In en, this message translates to:
  /// **'Retry Notification Access'**
  String get notificationSettingsRetryAccess;

  /// No description provided for @notificationSettingsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Push Notifications'**
  String get notificationSettingsEnable;

  /// No description provided for @notificationSettingsPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Permission granted'**
  String get notificationSettingsPermissionGranted;

  /// No description provided for @notificationSettingsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get notificationSettingsPermissionDenied;

  /// No description provided for @notificationSettingsPermissionProvisional.
  ///
  /// In en, this message translates to:
  /// **'Permission provisional'**
  String get notificationSettingsPermissionProvisional;

  /// No description provided for @notificationSettingsPermissionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Permission not requested yet'**
  String get notificationSettingsPermissionUnknown;

  /// No description provided for @notificationSettingsDeviceRegistered.
  ///
  /// In en, this message translates to:
  /// **'Device registered {date}.'**
  String notificationSettingsDeviceRegistered(String date);

  /// No description provided for @notificationSettingsDeviceNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Device registration not available yet.'**
  String get notificationSettingsDeviceNotRegistered;

  /// No description provided for @notificationSettingsDateRecently.
  ///
  /// In en, this message translates to:
  /// **'recently'**
  String get notificationSettingsDateRecently;

  /// No description provided for @notificationSettingsResultGranted.
  ///
  /// In en, this message translates to:
  /// **'Notification access granted and device registration refreshed.'**
  String get notificationSettingsResultGranted;

  /// No description provided for @notificationSettingsResultProvisional.
  ///
  /// In en, this message translates to:
  /// **'Notification access is provisional; device registration refreshed.'**
  String get notificationSettingsResultProvisional;

  /// No description provided for @notificationSettingsResultDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification access was denied.'**
  String get notificationSettingsResultDenied;

  /// No description provided for @notificationSettingsResultUnknown.
  ///
  /// In en, this message translates to:
  /// **'Notification status is still unavailable on this device.'**
  String get notificationSettingsResultUnknown;

  /// No description provided for @searchHintText.
  ///
  /// In en, this message translates to:
  /// **'Search messages, channels, or contacts...'**
  String get searchHintText;

  /// No description provided for @searchIdleText.
  ///
  /// In en, this message translates to:
  /// **'Type to search messages, channels, or contacts.'**
  String get searchIdleText;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get searchNoResults;

  /// No description provided for @searchRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get searchRetry;

  /// No description provided for @searchFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Search failed.'**
  String get searchFailedFallback;

  /// No description provided for @searchSectionChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get searchSectionChannels;

  /// No description provided for @searchSectionContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get searchSectionContacts;

  /// No description provided for @searchSectionMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get searchSectionMessages;

  /// No description provided for @searchViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get searchViewAll;

  /// No description provided for @searchLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get searchLoadMore;

  /// No description provided for @searchFilterSender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get searchFilterSender;

  /// No description provided for @searchFilterChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get searchFilterChannel;

  /// No description provided for @searchFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchFilterClear;

  /// No description provided for @searchFilterNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get searchFilterNewest;

  /// No description provided for @searchFilterOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get searchFilterOldest;

  /// No description provided for @searchFilterBySenderTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by sender'**
  String get searchFilterBySenderTitle;

  /// No description provided for @searchFilterBySenderHint.
  ///
  /// In en, this message translates to:
  /// **'Enter sender name…'**
  String get searchFilterBySenderHint;

  /// No description provided for @searchFilterByChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by channel'**
  String get searchFilterByChannelTitle;

  /// No description provided for @searchFilterByChannelHint.
  ///
  /// In en, this message translates to:
  /// **'Enter channel name…'**
  String get searchFilterByChannelHint;

  /// No description provided for @searchFilterCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get searchFilterCancel;

  /// No description provided for @searchFilterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get searchFilterApply;

  /// No description provided for @searchFilterDateAny.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get searchFilterDateAny;

  /// No description provided for @searchFilterDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get searchFilterDateToday;

  /// No description provided for @searchFilterDateWeek.
  ///
  /// In en, this message translates to:
  /// **'Past week'**
  String get searchFilterDateWeek;

  /// No description provided for @searchFilterDateMonth.
  ///
  /// In en, this message translates to:
  /// **'Past month'**
  String get searchFilterDateMonth;

  /// No description provided for @searchCouldNotOpenConversation.
  ///
  /// In en, this message translates to:
  /// **'Could not open conversation.'**
  String get searchCouldNotOpenConversation;

  /// No description provided for @searchFilterFromPrefix.
  ///
  /// In en, this message translates to:
  /// **'From: {name}'**
  String searchFilterFromPrefix(String name);

  /// No description provided for @searchFilterInPrefix.
  ///
  /// In en, this message translates to:
  /// **'In: {name}'**
  String searchFilterInPrefix(String name);

  /// No description provided for @searchRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get searchRecentTitle;

  /// No description provided for @searchRecentClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchRecentClear;

  /// No description provided for @machinesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Machines'**
  String get machinesPageTitle;

  /// No description provided for @machinesAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Machine'**
  String get machinesAddButton;

  /// No description provided for @machinesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load machines.'**
  String get machinesLoadFailed;

  /// No description provided for @machinesRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Machine'**
  String get machinesRegisterTitle;

  /// No description provided for @machinesRegisterAction.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get machinesRegisterAction;

  /// No description provided for @machinesRegisterHelper.
  ///
  /// In en, this message translates to:
  /// **'Create a machine and reveal its API key once.'**
  String get machinesRegisterHelper;

  /// No description provided for @machinesRegisteredTitle.
  ///
  /// In en, this message translates to:
  /// **'Machine Registered'**
  String get machinesRegisteredTitle;

  /// No description provided for @machinesRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to register machine.'**
  String get machinesRegisterFailed;

  /// No description provided for @machinesRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Machine'**
  String get machinesRenameTitle;

  /// No description provided for @machinesRenameSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get machinesRenameSaveAction;

  /// No description provided for @machinesRenameHelper.
  ///
  /// In en, this message translates to:
  /// **'Update the machine label shown across the workspace.'**
  String get machinesRenameHelper;

  /// No description provided for @machinesRenamedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Machine renamed.'**
  String get machinesRenamedSnackbar;

  /// No description provided for @machinesRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename machine.'**
  String get machinesRenameFailed;

  /// No description provided for @machinesRotatedApiKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Rotated API Key'**
  String get machinesRotatedApiKeyTitle;

  /// No description provided for @machinesRotateApiKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rotate machine API key.'**
  String get machinesRotateApiKeyFailed;

  /// No description provided for @machinesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Machine?'**
  String get machinesDeleteTitle;

  /// No description provided for @machinesDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get machinesDeleteCancel;

  /// No description provided for @machinesDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get machinesDeleteConfirm;

  /// No description provided for @machinesDeletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Machine deleted.'**
  String get machinesDeletedSnackbar;

  /// No description provided for @machinesDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete machine.'**
  String get machinesDeleteFailed;

  /// No description provided for @machinesApiKeyRevealedNote.
  ///
  /// In en, this message translates to:
  /// **'This key is only revealed at creation or rotation time.'**
  String get machinesApiKeyRevealedNote;

  /// No description provided for @machinesApiKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'API key copied.'**
  String get machinesApiKeyCopied;

  /// No description provided for @machinesCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get machinesCopyButton;

  /// No description provided for @machinesDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get machinesDoneButton;

  /// No description provided for @machinesRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get machinesRetryButton;

  /// No description provided for @machinesLatestDaemon.
  ///
  /// In en, this message translates to:
  /// **'Latest daemon'**
  String get machinesLatestDaemon;

  /// No description provided for @machinesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No machines registered yet.'**
  String get machinesEmptyTitle;

  /// No description provided for @machinesEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Register a machine to attach runtimes and admin operations to this server.'**
  String get machinesEmptyDescription;

  /// No description provided for @machinesRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Register Machine'**
  String get machinesRegisterButton;

  /// No description provided for @machinesMenuRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get machinesMenuRename;

  /// No description provided for @machinesMenuRotateApiKey.
  ///
  /// In en, this message translates to:
  /// **'Rotate API Key'**
  String get machinesMenuRotateApiKey;

  /// No description provided for @machinesMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get machinesMenuDelete;

  /// No description provided for @machinesMetaHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get machinesMetaHost;

  /// No description provided for @machinesMetaOs.
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get machinesMetaOs;

  /// No description provided for @machinesMetaDaemon.
  ///
  /// In en, this message translates to:
  /// **'Daemon'**
  String get machinesMetaDaemon;

  /// No description provided for @machinesStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get machinesStatusOnline;

  /// No description provided for @machinesStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get machinesStatusOffline;

  /// No description provided for @machinesStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get machinesStatusError;

  /// No description provided for @machinesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Machine name'**
  String get machinesNameLabel;

  /// No description provided for @machinesNameDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get machinesNameDialogCancel;

  /// No description provided for @machinesDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This removes the machine from the server list.'**
  String machinesDeleteMessage(String name);

  /// No description provided for @machinesCopyApiKeyMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy the API key for {name} now.'**
  String machinesCopyApiKeyMessage(String name);

  /// No description provided for @machinesSummaryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} machine(s)'**
  String machinesSummaryCount(int count);

  /// No description provided for @machinesSummaryOnline.
  ///
  /// In en, this message translates to:
  /// **'{count} online'**
  String machinesSummaryOnline(int count);

  /// No description provided for @machinesApiKeyPrefix.
  ///
  /// In en, this message translates to:
  /// **'Key {prefix}...'**
  String machinesApiKeyPrefix(String prefix);

  /// No description provided for @machinesMenuWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get machinesMenuWorkspaces;

  /// No description provided for @workspacesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get workspacesPageTitle;

  /// No description provided for @workspacesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workspaces on this machine.'**
  String get workspacesEmpty;

  /// No description provided for @workspacesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load workspaces.'**
  String get workspacesLoadFailed;

  /// No description provided for @workspacesRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get workspacesRetryButton;

  /// No description provided for @workspacesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Workspace?'**
  String get workspacesDeleteTitle;

  /// No description provided for @workspacesDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace \"{name}\"? This cannot be undone.'**
  String workspacesDeleteMessage(String name);

  /// No description provided for @workspacesDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get workspacesDeleteCancel;

  /// No description provided for @workspacesDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get workspacesDeleteConfirm;

  /// No description provided for @workspacesDeletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Workspace deleted.'**
  String get workspacesDeletedSnackbar;

  /// No description provided for @workspacesDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete workspace.'**
  String get workspacesDeleteFailed;

  /// No description provided for @workspacesMetaPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get workspacesMetaPath;

  /// No description provided for @workspacesMetaAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get workspacesMetaAgent;

  /// No description provided for @workspacesStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get workspacesStatusActive;

  /// No description provided for @workspacesStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get workspacesStatusInactive;

  /// No description provided for @tasksLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tasks.'**
  String get tasksLoadFailed;

  /// No description provided for @tasksEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet.'**
  String get tasksEmptyAll;

  /// No description provided for @tasksNoChannelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No channels available.'**
  String get tasksNoChannelsAvailable;

  /// No description provided for @tasksCreatedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Task created.'**
  String get tasksCreatedSnackbar;

  /// No description provided for @tasksCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create task.'**
  String get tasksCreateFailed;

  /// No description provided for @tasksUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update task.'**
  String get tasksUpdateFailed;

  /// No description provided for @tasksRetryAction.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get tasksRetryAction;

  /// No description provided for @tasksDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Task?'**
  String get tasksDeleteTitle;

  /// No description provided for @tasksDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String tasksDeleteMessage(String title);

  /// No description provided for @tasksDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get tasksDeleteCancel;

  /// No description provided for @tasksDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tasksDeleteConfirm;

  /// No description provided for @tasksDeletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Task deleted.'**
  String get tasksDeletedSnackbar;

  /// No description provided for @tasksDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete task.'**
  String get tasksDeleteFailed;

  /// No description provided for @tasksClaimFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to claim task.'**
  String get tasksClaimFailed;

  /// No description provided for @tasksUnclaimFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to unclaim task.'**
  String get tasksUnclaimFailed;

  /// No description provided for @tasksHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksHeaderTitle;

  /// No description provided for @tasksNewButton.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get tasksNewButton;

  /// No description provided for @tasksSummaryTodo.
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get tasksSummaryTodo;

  /// No description provided for @tasksSummaryInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get tasksSummaryInProgress;

  /// No description provided for @tasksSummaryReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get tasksSummaryReview;

  /// No description provided for @tasksSummaryDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tasksSummaryDone;

  /// No description provided for @tasksSummaryClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get tasksSummaryClosed;

  /// No description provided for @tasksEmptyChannel.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this channel.'**
  String get tasksEmptyChannel;

  /// No description provided for @tasksFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tasksFilterAll;

  /// No description provided for @tasksSectionTodo.
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get tasksSectionTodo;

  /// No description provided for @tasksSectionInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get tasksSectionInProgress;

  /// No description provided for @tasksSectionInReview.
  ///
  /// In en, this message translates to:
  /// **'In Review'**
  String get tasksSectionInReview;

  /// No description provided for @tasksSectionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tasksSectionDone;

  /// No description provided for @tasksSectionClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get tasksSectionClosed;

  /// No description provided for @tasksActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Task actions'**
  String get tasksActionsTooltip;

  /// No description provided for @tasksSwipeDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tasksSwipeDone;

  /// No description provided for @tasksActionMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark Done'**
  String get tasksActionMarkDone;

  /// No description provided for @tasksActionClose.
  ///
  /// In en, this message translates to:
  /// **'Close Task'**
  String get tasksActionClose;

  /// No description provided for @tasksActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get tasksActionStart;

  /// No description provided for @tasksActionMoveToReview.
  ///
  /// In en, this message translates to:
  /// **'Move to Review'**
  String get tasksActionMoveToReview;

  /// No description provided for @tasksActionReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get tasksActionReopen;

  /// No description provided for @tasksActionRevertInProgress.
  ///
  /// In en, this message translates to:
  /// **'Revert to In Progress'**
  String get tasksActionRevertInProgress;

  /// No description provided for @tasksActionRevertTodo.
  ///
  /// In en, this message translates to:
  /// **'Revert to To Do'**
  String get tasksActionRevertTodo;

  /// No description provided for @tasksActionClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get tasksActionClaim;

  /// No description provided for @tasksActionUnclaim.
  ///
  /// In en, this message translates to:
  /// **'Unclaim'**
  String get tasksActionUnclaim;

  /// No description provided for @tasksActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tasksActionDelete;

  /// No description provided for @tasksRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get tasksRetryButton;

  /// No description provided for @tasksCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Task'**
  String get tasksCreateTitle;

  /// No description provided for @tasksCreateChannelLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get tasksCreateChannelLabel;

  /// No description provided for @tasksCreateTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get tasksCreateTitleLabel;

  /// No description provided for @tasksCreateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get tasksCreateCancel;

  /// No description provided for @tasksCreateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get tasksCreateConfirm;

  /// No description provided for @tasksAccessibilityTodo.
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get tasksAccessibilityTodo;

  /// No description provided for @tasksAccessibilityInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get tasksAccessibilityInProgress;

  /// No description provided for @tasksAccessibilityInReview.
  ///
  /// In en, this message translates to:
  /// **'In Review'**
  String get tasksAccessibilityInReview;

  /// No description provided for @tasksAccessibilityDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tasksAccessibilityDone;

  /// No description provided for @tasksAccessibilityClosed.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tasksAccessibilityClosed;

  /// No description provided for @screenshotAnnotateNoCapture.
  ///
  /// In en, this message translates to:
  /// **'No screenshot captured'**
  String get screenshotAnnotateNoCapture;

  /// No description provided for @screenshotAnnotateDiscardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get screenshotAnnotateDiscardTooltip;

  /// No description provided for @screenshotAnnotateTitle.
  ///
  /// In en, this message translates to:
  /// **'Annotate Screenshot'**
  String get screenshotAnnotateTitle;

  /// No description provided for @screenshotAnnotateSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get screenshotAnnotateSaveTooltip;

  /// No description provided for @screenshotAnnotateShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get screenshotAnnotateShareTooltip;

  /// No description provided for @screenshotAnnotateAddTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Text'**
  String get screenshotAnnotateAddTextTitle;

  /// No description provided for @screenshotAnnotateTextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text...'**
  String get screenshotAnnotateTextHint;

  /// No description provided for @screenshotAnnotateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get screenshotAnnotateCancel;

  /// No description provided for @screenshotAnnotateAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get screenshotAnnotateAddButton;

  /// No description provided for @screenshotAnnotateExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export screenshot'**
  String get screenshotAnnotateExportFailed;

  /// No description provided for @screenshotAnnotateExportError.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String screenshotAnnotateExportError(String error);

  /// No description provided for @screenshotAnnotateSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String screenshotAnnotateSaveFailed(String error);

  /// No description provided for @screenshotAnnotateShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get screenshotAnnotateShareSubject;

  /// No description provided for @dateSeparatorToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateSeparatorToday;

  /// No description provided for @dateSeparatorYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateSeparatorYesterday;

  /// No description provided for @conversationComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get conversationComposerHint;

  /// No description provided for @conversationComposerAttachPhotoVideo.
  ///
  /// In en, this message translates to:
  /// **'Photo & Video'**
  String get conversationComposerAttachPhotoVideo;

  /// No description provided for @conversationComposerAttachCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get conversationComposerAttachCamera;

  /// No description provided for @conversationComposerAttachFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get conversationComposerAttachFile;

  /// No description provided for @conversationComposerSendFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message.'**
  String get conversationComposerSendFailedFallback;

  /// No description provided for @conversationComposerAttachTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get conversationComposerAttachTooltip;

  /// No description provided for @conversationComposerFormattingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Formatting'**
  String get conversationComposerFormattingTooltip;

  /// No description provided for @conversationComposerEmojiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get conversationComposerEmojiTooltip;

  /// No description provided for @conversationComposerCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Please check permissions.'**
  String get conversationComposerCameraUnavailable;

  /// No description provided for @conversationContextEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get conversationContextEditMessage;

  /// No description provided for @conversationContextReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get conversationContextReply;

  /// No description provided for @conversationContextSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get conversationContextSelect;

  /// No description provided for @conversationContextReact.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get conversationContextReact;

  /// No description provided for @conversationContextTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get conversationContextTranslate;

  /// No description provided for @conversationContextCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get conversationContextCopyText;

  /// No description provided for @conversationContextForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get conversationContextForward;

  /// No description provided for @conversationContextSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Save message'**
  String get conversationContextSaveMessage;

  /// No description provided for @conversationContextUnsaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Unsave message'**
  String get conversationContextUnsaveMessage;

  /// No description provided for @conversationContextPinMessage.
  ///
  /// In en, this message translates to:
  /// **'Pin message'**
  String get conversationContextPinMessage;

  /// No description provided for @conversationContextUnpinMessage.
  ///
  /// In en, this message translates to:
  /// **'Unpin message'**
  String get conversationContextUnpinMessage;

  /// No description provided for @conversationContextReplyInThread.
  ///
  /// In en, this message translates to:
  /// **'Reply in thread'**
  String get conversationContextReplyInThread;

  /// No description provided for @conversationContextCreateTask.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get conversationContextCreateTask;

  /// No description provided for @conversationContextDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get conversationContextDeleteMessage;

  /// No description provided for @conversationSelectionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get conversationSelectionCancel;

  /// No description provided for @conversationSelectionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get conversationSelectionSave;

  /// No description provided for @conversationSelectionExportAsImage.
  ///
  /// In en, this message translates to:
  /// **'Export as image'**
  String get conversationSelectionExportAsImage;

  /// No description provided for @conversationSelectionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get conversationSelectionDelete;

  /// No description provided for @conversationSelectionSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String conversationSelectionSelected(int count);

  /// No description provided for @conversationSelectionBatchSucceeded.
  ///
  /// In en, this message translates to:
  /// **'{count} {action}.'**
  String conversationSelectionBatchSucceeded(int count, String action);

  /// No description provided for @conversationSelectionBatchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to {action} {count} message(s).'**
  String conversationSelectionBatchFailed(String action, int count);

  /// No description provided for @conversationSelectionBatchPartial.
  ///
  /// In en, this message translates to:
  /// **'{succeeded} {action}, {failed} failed.'**
  String conversationSelectionBatchPartial(
      int succeeded, String action, int failed);

  /// No description provided for @conversationSelectionActionSaveVerb.
  ///
  /// In en, this message translates to:
  /// **'save'**
  String get conversationSelectionActionSaveVerb;

  /// No description provided for @conversationSelectionActionSaved.
  ///
  /// In en, this message translates to:
  /// **'saved'**
  String get conversationSelectionActionSaved;

  /// No description provided for @conversationSelectionActionDeleteVerb.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get conversationSelectionActionDeleteVerb;

  /// No description provided for @conversationSelectionActionDeleted.
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get conversationSelectionActionDeleted;

  /// No description provided for @conversationEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get conversationEditDialogTitle;

  /// No description provided for @conversationEditDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get conversationEditDialogCancel;

  /// No description provided for @conversationEditDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get conversationEditDialogSave;

  /// No description provided for @conversationEditSuccess.
  ///
  /// In en, this message translates to:
  /// **'Message edited.'**
  String get conversationEditSuccess;

  /// No description provided for @conversationEditFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to edit message.'**
  String get conversationEditFailedFallback;

  /// No description provided for @conversationMessageDeletedPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'[Message deleted]'**
  String get conversationMessageDeletedPlaceholder;

  /// No description provided for @conversationReactionFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to add reaction.'**
  String get conversationReactionFailedFallback;

  /// No description provided for @conversationReactWithEmojiTitle.
  ///
  /// In en, this message translates to:
  /// **'React with emoji'**
  String get conversationReactWithEmojiTitle;

  /// No description provided for @conversationReactWithEmojiSemantics.
  ///
  /// In en, this message translates to:
  /// **'React with {emoji}'**
  String conversationReactWithEmojiSemantics(String emoji);

  /// No description provided for @conversationReactionUpdateFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to update reaction.'**
  String get conversationReactionUpdateFailedFallback;

  /// No description provided for @conversationDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get conversationDeleteDialogTitle;

  /// No description provided for @conversationDeleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This message will be permanently deleted.'**
  String get conversationDeleteDialogContent;

  /// No description provided for @conversationDeleteDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get conversationDeleteDialogCancel;

  /// No description provided for @conversationDeleteDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get conversationDeleteDialogConfirm;

  /// No description provided for @conversationDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Message deleted.'**
  String get conversationDeleteSuccess;

  /// No description provided for @conversationDeleteFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete message.'**
  String get conversationDeleteFailedFallback;

  /// No description provided for @conversationOpenLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Link'**
  String get conversationOpenLinkTitle;

  /// No description provided for @conversationOpenLinkContent.
  ///
  /// In en, this message translates to:
  /// **'Open {url}?'**
  String conversationOpenLinkContent(String url);

  /// No description provided for @conversationOpenLinkCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get conversationOpenLinkCancel;

  /// No description provided for @conversationOpenLinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get conversationOpenLinkConfirm;

  /// No description provided for @conversationMessageActionsSemantics.
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get conversationMessageActionsSemantics;

  /// No description provided for @conversationShowMessageMenuSemantics.
  ///
  /// In en, this message translates to:
  /// **'Show message menu'**
  String get conversationShowMessageMenuSemantics;

  /// No description provided for @conversationReplySemantics.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get conversationReplySemantics;

  /// No description provided for @channelStopAllAgents.
  ///
  /// In en, this message translates to:
  /// **'Stop All Agents'**
  String get channelStopAllAgents;

  /// No description provided for @channelResumeAllAgents.
  ///
  /// In en, this message translates to:
  /// **'Resume All Agents'**
  String get channelResumeAllAgents;

  /// No description provided for @channelStopAllAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop all agents'**
  String get channelStopAllAgentsTitle;

  /// No description provided for @channelStopAllAgentsMessage.
  ///
  /// In en, this message translates to:
  /// **'Stop all agents in this channel? They will not respond until resumed.'**
  String get channelStopAllAgentsMessage;

  /// No description provided for @channelStopAllAgentsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop All'**
  String get channelStopAllAgentsConfirm;

  /// No description provided for @channelStopAllAgentsSuccess.
  ///
  /// In en, this message translates to:
  /// **'All agents stopped.'**
  String get channelStopAllAgentsSuccess;

  /// No description provided for @channelStopAllAgentsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop agents.'**
  String get channelStopAllAgentsFailed;

  /// No description provided for @channelResumeAllAgentsSuccess.
  ///
  /// In en, this message translates to:
  /// **'All agents resumed.'**
  String get channelResumeAllAgentsSuccess;

  /// No description provided for @channelResumeAllAgentsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to resume agents.'**
  String get channelResumeAllAgentsFailed;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to perform this action.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested resource was not found.'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'A conflict occurred. Please refresh and try again.'**
  String get errorConflict;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Invalid input. Please check and try again.'**
  String get errorValidation;

  /// No description provided for @errorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get errorRateLimit;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errorServer;

  /// No description provided for @errorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request was cancelled.'**
  String get errorCancelled;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// No description provided for @pendingNewMessages.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get pendingNewMessages;

  /// No description provided for @pendingSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get pendingSending;

  /// No description provided for @pendingQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued — waiting for connection'**
  String get pendingQueued;

  /// No description provided for @pendingSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get pendingSent;

  /// No description provided for @pendingFailedToSend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send'**
  String get pendingFailedToSend;

  /// No description provided for @pendingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get pendingRetry;

  /// No description provided for @pendingDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get pendingDismiss;

  /// No description provided for @pendingEarlierHistoryLimited.
  ///
  /// In en, this message translates to:
  /// **'Earlier history is limited.'**
  String get pendingEarlierHistoryLimited;

  /// No description provided for @composerSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get composerSendTooltip;

  /// No description provided for @composerVoiceMessageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get composerVoiceMessageTooltip;

  /// No description provided for @composerFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large. Maximum size: 50 MB'**
  String get composerFileTooLarge;

  /// No description provided for @messageSenderYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get messageSenderYou;

  /// No description provided for @channelActionMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get channelActionMoveUp;

  /// No description provided for @channelActionMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get channelActionMoveDown;

  /// No description provided for @channelActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin channel'**
  String get channelActionPin;

  /// No description provided for @channelActionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin channel'**
  String get channelActionUnpin;

  /// No description provided for @channelActionMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as Unread'**
  String get channelActionMarkUnread;

  /// No description provided for @channelActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit channel'**
  String get channelActionEdit;

  /// No description provided for @channelActionLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave channel'**
  String get channelActionLeave;

  /// No description provided for @channelActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete channel'**
  String get channelActionDelete;

  /// No description provided for @channelsSortAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'Sort A-Z'**
  String get channelsSortAlphabetical;

  /// No description provided for @channelsSortRecent.
  ///
  /// In en, this message translates to:
  /// **'Sort by recent'**
  String get channelsSortRecent;

  /// No description provided for @channelsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get channelsMarkAllRead;

  /// No description provided for @channelsClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get channelsClearSearch;

  /// No description provided for @channelsMarkedUnread.
  ///
  /// In en, this message translates to:
  /// **'Marked as unread'**
  String get channelsMarkedUnread;

  /// No description provided for @channelsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New Channel'**
  String get channelsCreateTitle;

  /// No description provided for @channelsCreateSectionName.
  ///
  /// In en, this message translates to:
  /// **'CHANNEL NAME'**
  String get channelsCreateSectionName;

  /// No description provided for @channelsCreateNameHint.
  ///
  /// In en, this message translates to:
  /// **'channel-name'**
  String get channelsCreateNameHint;

  /// No description provided for @channelsCreateSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION (OPTIONAL)'**
  String get channelsCreateSectionDescription;

  /// No description provided for @channelsCreateDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What is this channel about?'**
  String get channelsCreateDescriptionHint;

  /// No description provided for @channelsCreateSectionVisibility.
  ///
  /// In en, this message translates to:
  /// **'VISIBILITY'**
  String get channelsCreateSectionVisibility;

  /// No description provided for @channelsCreateSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get channelsCreateSubmitting;

  /// No description provided for @channelsCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create Channel'**
  String get channelsCreateSubmit;

  /// No description provided for @channelsCreateNoServer.
  ///
  /// In en, this message translates to:
  /// **'No active server selected.'**
  String get channelsCreateNoServer;

  /// No description provided for @channelsCreateVisibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get channelsCreateVisibilityPublic;

  /// No description provided for @channelsCreateVisibilityPublicSub.
  ///
  /// In en, this message translates to:
  /// **'Visible to all'**
  String get channelsCreateVisibilityPublicSub;

  /// No description provided for @channelsCreateVisibilityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get channelsCreateVisibilityPrivate;

  /// No description provided for @channelsCreateVisibilityPrivateSub.
  ///
  /// In en, this message translates to:
  /// **'Invite only'**
  String get channelsCreateVisibilityPrivateSub;

  /// No description provided for @channelsMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel Members'**
  String get channelsMembersTitle;

  /// No description provided for @channelsMembersRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get channelsMembersRetry;

  /// No description provided for @channelsMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No members in this channel.'**
  String get channelsMembersEmpty;

  /// No description provided for @channelsMembersTypeAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get channelsMembersTypeAgent;

  /// No description provided for @channelsMembersTypeHuman.
  ///
  /// In en, this message translates to:
  /// **'Human'**
  String get channelsMembersTypeHuman;

  /// No description provided for @channelsMembersMessageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get channelsMembersMessageTooltip;

  /// No description provided for @channelsMembersRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Member?'**
  String get channelsMembersRemoveTitle;

  /// No description provided for @channelsMembersRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this channel?'**
  String channelsMembersRemoveMessage(String name);

  /// No description provided for @channelsMembersRemoveCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get channelsMembersRemoveCancel;

  /// No description provided for @channelsMembersRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get channelsMembersRemoveConfirm;

  /// No description provided for @channelsAddMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get channelsAddMemberTitle;

  /// No description provided for @channelsAddMemberTabHumans.
  ///
  /// In en, this message translates to:
  /// **'Humans'**
  String get channelsAddMemberTabHumans;

  /// No description provided for @channelsAddMemberTabAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get channelsAddMemberTabAgents;

  /// No description provided for @channelsAddMemberClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get channelsAddMemberClose;

  /// No description provided for @channelsAddMemberNoHumans.
  ///
  /// In en, this message translates to:
  /// **'No more humans to add.'**
  String get channelsAddMemberNoHumans;

  /// No description provided for @channelsAddMemberNoAgents.
  ///
  /// In en, this message translates to:
  /// **'No more agents to add.'**
  String get channelsAddMemberNoAgents;

  /// No description provided for @channelsDialogCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create channel'**
  String get channelsDialogCreateTitle;

  /// No description provided for @channelsDialogCreateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get channelsDialogCreateNameLabel;

  /// No description provided for @channelsDialogCreateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get channelsDialogCreateCancel;

  /// No description provided for @channelsDialogCreateSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get channelsDialogCreateSubmitting;

  /// No description provided for @channelsDialogCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get channelsDialogCreateSubmit;

  /// No description provided for @channelsDialogEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit channel'**
  String get channelsDialogEditTitle;

  /// No description provided for @channelsDialogEditNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get channelsDialogEditNameLabel;

  /// No description provided for @channelsDialogEditCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get channelsDialogEditCancel;

  /// No description provided for @channelsDialogEditSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get channelsDialogEditSubmitting;

  /// No description provided for @channelsDialogEditSubmit.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get channelsDialogEditSubmit;

  /// No description provided for @channelsDialogConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get channelsDialogConfirmCancel;

  /// No description provided for @channelsDialogConfirmWorking.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get channelsDialogConfirmWorking;

  /// No description provided for @serversInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Workspace'**
  String get serversInviteTitle;

  /// No description provided for @serversInviteJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining workspace...'**
  String get serversInviteJoining;

  /// No description provided for @serversInviteFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to join workspace.'**
  String get serversInviteFailedFallback;

  /// No description provided for @serversInviteRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get serversInviteRetry;

  /// No description provided for @serversInviteGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get serversInviteGoHome;

  /// No description provided for @serversInviteDescription.
  ///
  /// In en, this message translates to:
  /// **'You have been invited to join a workspace.'**
  String get serversInviteDescription;

  /// No description provided for @serversInviteAccept.
  ///
  /// In en, this message translates to:
  /// **'Join workspace'**
  String get serversInviteAccept;

  /// No description provided for @serversInviteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get serversInviteCancel;

  /// No description provided for @serversInviteSuccessNamed.
  ///
  /// In en, this message translates to:
  /// **'Joined {name}!'**
  String serversInviteSuccessNamed(String name);

  /// No description provided for @serversInviteSuccessGeneric.
  ///
  /// In en, this message translates to:
  /// **'Joined workspace!'**
  String get serversInviteSuccessGeneric;

  /// No description provided for @serversInviteContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get serversInviteContinue;

  /// No description provided for @serversDialogCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create workspace'**
  String get serversDialogCreateTitle;

  /// No description provided for @serversDialogCreateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace name'**
  String get serversDialogCreateNameLabel;

  /// No description provided for @serversDialogCreateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get serversDialogCreateCancel;

  /// No description provided for @serversDialogCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get serversDialogCreateSubmit;

  /// No description provided for @serversDialogRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename workspace'**
  String get serversDialogRenameTitle;

  /// No description provided for @serversDialogRenameNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace name'**
  String get serversDialogRenameNameLabel;

  /// No description provided for @serversDialogRenameCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get serversDialogRenameCancel;

  /// No description provided for @serversDialogRenameSubmit.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get serversDialogRenameSubmit;

  /// No description provided for @serversDialogJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join workspace'**
  String get serversDialogJoinTitle;

  /// No description provided for @serversDialogJoinLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code or link'**
  String get serversDialogJoinLabel;

  /// No description provided for @serversDialogJoinHint.
  ///
  /// In en, this message translates to:
  /// **'https://slock.ai/invite/token-123'**
  String get serversDialogJoinHint;

  /// No description provided for @serversDialogJoinCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get serversDialogJoinCancel;

  /// No description provided for @serversDialogJoinSubmit.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get serversDialogJoinSubmit;

  /// No description provided for @serversDialogConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get serversDialogConfirmCancel;

  /// No description provided for @serversSwitcherTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch workspace'**
  String get serversSwitcherTitle;

  /// No description provided for @serversSwitcherCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get serversSwitcherCreating;

  /// No description provided for @serversSwitcherCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create workspace'**
  String get serversSwitcherCreateAction;

  /// No description provided for @serversSwitcherJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining...'**
  String get serversSwitcherJoining;

  /// No description provided for @serversSwitcherJoinAction.
  ///
  /// In en, this message translates to:
  /// **'Join workspace'**
  String get serversSwitcherJoinAction;

  /// No description provided for @serversSwitcherEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workspaces available.'**
  String get serversSwitcherEmpty;

  /// No description provided for @serversSwitcherSettings.
  ///
  /// In en, this message translates to:
  /// **'Workspace Settings'**
  String get serversSwitcherSettings;

  /// No description provided for @serversSwitcherCreatedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Workspace created.'**
  String get serversSwitcherCreatedSnackbar;

  /// No description provided for @serversSwitcherJoinedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Workspace joined.'**
  String get serversSwitcherJoinedSnackbar;

  /// No description provided for @serversSwitcherDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace?'**
  String get serversSwitcherDeleteTitle;

  /// No description provided for @serversSwitcherDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This permanently removes the workspace.'**
  String serversSwitcherDeleteMessage(String name);

  /// No description provided for @serversSwitcherDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get serversSwitcherDeleteConfirm;

  /// No description provided for @serversSwitcherDeletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Workspace deleted.'**
  String get serversSwitcherDeletedSnackbar;

  /// No description provided for @serversSwitcherLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave workspace?'**
  String get serversSwitcherLeaveTitle;

  /// No description provided for @serversSwitcherLeaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}? You can rejoin later with a new invite.'**
  String serversSwitcherLeaveMessage(String name);

  /// No description provided for @serversSwitcherLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get serversSwitcherLeaveConfirm;

  /// No description provided for @serversSwitcherLeftSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Workspace left.'**
  String get serversSwitcherLeftSnackbar;

  /// No description provided for @serversSwitcherRenamedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Workspace renamed.'**
  String get serversSwitcherRenamedSnackbar;

  /// No description provided for @serversSwitcherRowRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get serversSwitcherRowRename;

  /// No description provided for @serversSwitcherRowDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace'**
  String get serversSwitcherRowDelete;

  /// No description provided for @serversSwitcherRowLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave workspace'**
  String get serversSwitcherRowLeave;

  /// No description provided for @serversSwitcherRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get serversSwitcherRetry;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Slock'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get onboardingFinish;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your workspace'**
  String get onboardingSetupTitle;

  /// No description provided for @onboardingSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Slock is ready. Take a minute to configure notifications and your profile before jumping in.'**
  String get onboardingSetupBody;

  /// No description provided for @onboardingNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay in the loop'**
  String get onboardingNotificationsTitle;

  /// No description provided for @onboardingNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications so mentions, replies, and tasks reach you quickly.'**
  String get onboardingNotificationsBody;

  /// No description provided for @onboardingNotificationsButton.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get onboardingNotificationsButton;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Add your display name, bio, or avatar so teammates can recognize you.'**
  String get onboardingProfileBody;

  /// No description provided for @onboardingProfileButton.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get onboardingProfileButton;

  /// No description provided for @agentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No agents yet.'**
  String get agentsEmptyTitle;

  /// No description provided for @agentsSelectServerFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a server first.'**
  String get agentsSelectServerFirst;

  /// No description provided for @agentsCreated.
  ///
  /// In en, this message translates to:
  /// **'Agent created.'**
  String get agentsCreated;

  /// No description provided for @agentsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Agent updated.'**
  String get agentsUpdated;

  /// No description provided for @agentsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Agent deleted.'**
  String get agentsDeleted;

  /// No description provided for @agentsResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Agent reset.'**
  String get agentsResetSuccess;

  /// No description provided for @agentsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Agent?'**
  String get agentsDeleteTitle;

  /// No description provided for @agentsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This removes the agent configuration from the workspace.'**
  String agentsDeleteMessage(String name);

  /// No description provided for @agentsStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop Agent?'**
  String get agentsStopTitle;

  /// No description provided for @agentsStopMessage.
  ///
  /// In en, this message translates to:
  /// **'Stop {name}? The agent will finish its current action before stopping.'**
  String agentsStopMessage(String name);

  /// No description provided for @agentsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Session?'**
  String get agentsResetTitle;

  /// No description provided for @agentsResetMessage.
  ///
  /// In en, this message translates to:
  /// **'Reset {name}? This clears the agent\'s conversation history.'**
  String agentsResetMessage(String name);

  /// No description provided for @agentsSummary.
  ///
  /// In en, this message translates to:
  /// **'{active} active / {stopped} stopped'**
  String agentsSummary(int active, int stopped);

  /// No description provided for @agentsActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get agentsActionStart;

  /// No description provided for @agentsActionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get agentsActionStop;

  /// No description provided for @agentsActionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get agentsActionReset;

  /// No description provided for @agentsActionResetSession.
  ///
  /// In en, this message translates to:
  /// **'Reset Session'**
  String get agentsActionResetSession;

  /// No description provided for @agentsActionMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get agentsActionMessage;

  /// No description provided for @agentsActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get agentsActionDelete;

  /// No description provided for @agentsActionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get agentsActionCancel;

  /// No description provided for @agentsAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentsAppBarTitle;

  /// No description provided for @agentsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load agents.'**
  String get agentsFailedToLoad;

  /// No description provided for @agentsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Agent not found.'**
  String get agentsNotFound;

  /// No description provided for @agentsActivityLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Log'**
  String get agentsActivityLogTitle;

  /// No description provided for @agentsActivityLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity log entries.'**
  String get agentsActivityLogEmpty;

  /// No description provided for @agentsConfigMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get agentsConfigMachine;

  /// No description provided for @agentsConfigRuntime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get agentsConfigRuntime;

  /// No description provided for @agentsConfigModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get agentsConfigModel;

  /// No description provided for @agentsConfigReasoning.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get agentsConfigReasoning;

  /// No description provided for @agentsEnvVarsTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment Variables'**
  String get agentsEnvVarsTitle;

  /// No description provided for @agentsEnvVarsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No environment variables'**
  String get agentsEnvVarsEmpty;

  /// No description provided for @agentsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get agentsRetry;

  /// No description provided for @agentsActivityOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get agentsActivityOnline;

  /// No description provided for @agentsActivityThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get agentsActivityThinking;

  /// No description provided for @agentsActivityWorking.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get agentsActivityWorking;

  /// No description provided for @agentsActivityError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get agentsActivityError;

  /// No description provided for @agentsActivityErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Error: {detail}'**
  String agentsActivityErrorDetail(String detail);

  /// No description provided for @agentsActivityOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get agentsActivityOffline;

  /// No description provided for @agentsFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Agent'**
  String get agentsFormEditTitle;

  /// No description provided for @agentsFormCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Agent'**
  String get agentsFormCreateTitle;

  /// No description provided for @agentsFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get agentsFormNameRequired;

  /// No description provided for @agentsFormMachineRequired.
  ///
  /// In en, this message translates to:
  /// **'Machine is required.'**
  String get agentsFormMachineRequired;

  /// No description provided for @agentsFormRuntimeRequired.
  ///
  /// In en, this message translates to:
  /// **'Runtime is required.'**
  String get agentsFormRuntimeRequired;

  /// No description provided for @agentsFormModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Model is required.'**
  String get agentsFormModelRequired;

  /// No description provided for @agentsFormNoMachines.
  ///
  /// In en, this message translates to:
  /// **'No machines available for this server.'**
  String get agentsFormNoMachines;

  /// No description provided for @agentsFormLabelMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get agentsFormLabelMachine;

  /// No description provided for @agentsFormLabelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get agentsFormLabelName;

  /// No description provided for @agentsFormLabelDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get agentsFormLabelDescription;

  /// No description provided for @agentsFormLabelRuntime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get agentsFormLabelRuntime;

  /// No description provided for @agentsFormLabelModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get agentsFormLabelModel;

  /// No description provided for @agentsFormLabelReasoningEffort.
  ///
  /// In en, this message translates to:
  /// **'Reasoning Effort'**
  String get agentsFormLabelReasoningEffort;

  /// No description provided for @agentsFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get agentsFormSave;

  /// No description provided for @agentsFormCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get agentsFormCreate;

  /// No description provided for @agentsFormCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get agentsFormCancel;

  /// No description provided for @agentsFormRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get agentsFormRetry;

  /// No description provided for @agentsReasoningLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get agentsReasoningLow;

  /// No description provided for @agentsReasoningMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get agentsReasoningMedium;

  /// No description provided for @agentsReasoningHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get agentsReasoningHigh;

  /// No description provided for @agentsReasoningExtraHigh.
  ///
  /// In en, this message translates to:
  /// **'Extra High'**
  String get agentsReasoningExtraHigh;

  /// No description provided for @agentsFormConfiguredDefault.
  ///
  /// In en, this message translates to:
  /// **'Configured Default'**
  String get agentsFormConfiguredDefault;

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditTitle;

  /// No description provided for @profileEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileEditSave;

  /// No description provided for @profileEditSnackbarSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileEditSnackbarSaved;

  /// No description provided for @profileEditSnackbarAvatarSavedProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated. Profile save failed — tap Save to retry.'**
  String get profileEditSnackbarAvatarSavedProfileFailed;

  /// No description provided for @profileEditNewAvatarSelected.
  ///
  /// In en, this message translates to:
  /// **'New avatar selected'**
  String get profileEditNewAvatarSelected;

  /// No description provided for @profileEditChangeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get profileEditChangeAvatar;

  /// No description provided for @profileEditSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Profile details'**
  String get profileEditSectionDetails;

  /// No description provided for @profileEditDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileEditDisplayNameLabel;

  /// No description provided for @profileEditDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required.'**
  String get profileEditDisplayNameRequired;

  /// No description provided for @profileEditBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio / status'**
  String get profileEditBioLabel;

  /// No description provided for @profileTitleSelf.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profileTitleSelf;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get profileRetry;

  /// No description provided for @profileNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Profile not available.'**
  String get profileNotAvailable;

  /// No description provided for @profileLabelUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get profileLabelUserId;

  /// No description provided for @profileLabelUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileLabelUsername;

  /// No description provided for @profileLabelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileLabelEmail;

  /// No description provided for @profileLabelRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get profileLabelRole;

  /// No description provided for @profileLabelMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get profileLabelMemberSince;

  /// No description provided for @profileEditComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Profile editing coming soon'**
  String get profileEditComingSoon;

  /// No description provided for @profileEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditButton;

  /// No description provided for @profileThisIsYou.
  ///
  /// In en, this message translates to:
  /// **'This is you'**
  String get profileThisIsYou;

  /// No description provided for @profileMessageButton.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileMessageButton;

  /// No description provided for @profileDateFormat.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String profileDateFormat(String month, int day, int year);

  /// No description provided for @profileMonthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get profileMonthJan;

  /// No description provided for @profileMonthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get profileMonthFeb;

  /// No description provided for @profileMonthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get profileMonthMar;

  /// No description provided for @profileMonthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get profileMonthApr;

  /// No description provided for @profileMonthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get profileMonthMay;

  /// No description provided for @profileMonthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get profileMonthJun;

  /// No description provided for @profileMonthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get profileMonthJul;

  /// No description provided for @profileMonthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get profileMonthAug;

  /// No description provided for @profileMonthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get profileMonthSep;

  /// No description provided for @profileMonthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get profileMonthOct;

  /// No description provided for @profileMonthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get profileMonthNov;

  /// No description provided for @profileMonthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get profileMonthDec;

  /// No description provided for @settingsEditProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfileTitle;

  /// No description provided for @settingsEditProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your display name, bio, and avatar'**
  String get settingsEditProfileSubtitle;

  /// No description provided for @inboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inboxTitle;

  /// No description provided for @inboxMarkAllReadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get inboxMarkAllReadTooltip;

  /// No description provided for @inboxLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load inbox'**
  String get inboxLoadFailed;

  /// No description provided for @inboxRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get inboxRetry;

  /// No description provided for @inboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get inboxEmptyTitle;

  /// No description provided for @inboxEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No messages in your inbox'**
  String get inboxEmptySubtitle;

  /// No description provided for @inboxActionMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark Read'**
  String get inboxActionMarkRead;

  /// No description provided for @inboxSwipeLabelRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get inboxSwipeLabelRead;

  /// No description provided for @inboxFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get inboxFilterUnread;

  /// No description provided for @inboxFilterMentions.
  ///
  /// In en, this message translates to:
  /// **'@Mentions'**
  String get inboxFilterMentions;

  /// No description provided for @inboxFilterDms.
  ///
  /// In en, this message translates to:
  /// **'DMs'**
  String get inboxFilterDms;

  /// No description provided for @inboxFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get inboxFilterAll;

  /// No description provided for @inboxMentionBadge.
  ///
  /// In en, this message translates to:
  /// **'@you'**
  String get inboxMentionBadge;

  /// No description provided for @inboxTimeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get inboxTimeNow;

  /// No description provided for @inboxTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String inboxTimeMinutes(int count);

  /// No description provided for @inboxTimeHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String inboxTimeHours(int count);

  /// No description provided for @inboxTimeDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String inboxTimeDays(int count);

  /// No description provided for @inboxUnreadCountOverflow.
  ///
  /// In en, this message translates to:
  /// **'99+'**
  String get inboxUnreadCountOverflow;

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

  /// No description provided for @settingsAppearanceThemeSection.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsAppearanceThemeSection;

  /// No description provided for @settingsThemeSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get settingsThemeSystemTitle;

  /// No description provided for @settingsThemeSystemDescription.
  ///
  /// In en, this message translates to:
  /// **'Use your device theme setting.'**
  String get settingsThemeSystemDescription;

  /// No description provided for @settingsThemeLightTitle.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLightTitle;

  /// No description provided for @settingsThemeLightDescription.
  ///
  /// In en, this message translates to:
  /// **'Always use the light theme.'**
  String get settingsThemeLightDescription;

  /// No description provided for @settingsThemeDarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDarkTitle;

  /// No description provided for @settingsThemeDarkDescription.
  ///
  /// In en, this message translates to:
  /// **'Always use the dark theme.'**
  String get settingsThemeDarkDescription;

  /// No description provided for @settingsDiagnosticsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnosticsPageTitle;

  /// No description provided for @settingsDiagnosticsEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{entry} other{entries}}'**
  String settingsDiagnosticsEntryCount(int count);

  /// No description provided for @settingsDiagnosticsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get settingsDiagnosticsFilterAll;

  /// No description provided for @settingsDiagnosticsFilterInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get settingsDiagnosticsFilterInfo;

  /// No description provided for @settingsDiagnosticsFilterWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get settingsDiagnosticsFilterWarning;

  /// No description provided for @settingsDiagnosticsFilterError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get settingsDiagnosticsFilterError;

  /// No description provided for @settingsDiagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No diagnostic entries'**
  String get settingsDiagnosticsEmpty;

  /// No description provided for @settingsDiagnosticsWorkerLoading.
  ///
  /// In en, this message translates to:
  /// **'Background worker: loading…'**
  String get settingsDiagnosticsWorkerLoading;

  /// No description provided for @settingsDiagnosticsWorkerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Background worker diagnostics unavailable'**
  String get settingsDiagnosticsWorkerUnavailable;

  /// No description provided for @settingsDiagnosticsWorkerNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Background worker: not running'**
  String get settingsDiagnosticsWorkerNotRunning;

  /// No description provided for @settingsDiagnosticsWorkerTitle.
  ///
  /// In en, this message translates to:
  /// **'Background worker'**
  String get settingsDiagnosticsWorkerTitle;

  /// No description provided for @settingsTranslationPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get settingsTranslationPageTitle;

  /// No description provided for @settingsTranslationNoActiveWorkspace.
  ///
  /// In en, this message translates to:
  /// **'No active workspace. Translation settings are workspace-level.'**
  String get settingsTranslationNoActiveWorkspace;

  /// No description provided for @settingsTranslationRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get settingsTranslationRetry;

  /// No description provided for @settingsTranslationSectionMode.
  ///
  /// In en, this message translates to:
  /// **'Translation Mode'**
  String get settingsTranslationSectionMode;

  /// No description provided for @settingsTranslationSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get settingsTranslationSectionLanguage;

  /// No description provided for @settingsTranslationModeAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get settingsTranslationModeAutoTitle;

  /// No description provided for @settingsTranslationModeManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get settingsTranslationModeManualTitle;

  /// No description provided for @settingsTranslationModeOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsTranslationModeOffTitle;

  /// No description provided for @settingsTranslationModeAutoDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically translate messages when entering a conversation'**
  String get settingsTranslationModeAutoDescription;

  /// No description provided for @settingsTranslationModeManualDescription.
  ///
  /// In en, this message translates to:
  /// **'Translate only when you tap the translate button'**
  String get settingsTranslationModeManualDescription;

  /// No description provided for @settingsTranslationModeOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Translation is disabled'**
  String get settingsTranslationModeOffDescription;

  /// No description provided for @billingTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billingTitle;

  /// No description provided for @billingUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing unavailable'**
  String get billingUnavailableTitle;

  /// No description provided for @billingUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not load billing details right now.'**
  String get billingUnavailableMessage;

  /// No description provided for @billingCouldNotOpenManagement.
  ///
  /// In en, this message translates to:
  /// **'Could not open billing management.'**
  String get billingCouldNotOpenManagement;

  /// No description provided for @billingSubscriptionManagement.
  ///
  /// In en, this message translates to:
  /// **'Subscription management'**
  String get billingSubscriptionManagement;

  /// No description provided for @billingSubscriptionManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Review your current subscription and open the billing portal when management is available.'**
  String get billingSubscriptionManagementDesc;

  /// No description provided for @billingSubscriptionSummary.
  ///
  /// In en, this message translates to:
  /// **'Subscription summary'**
  String get billingSubscriptionSummary;

  /// No description provided for @billingStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get billingStatusUnavailable;

  /// No description provided for @billingCurrentPrice.
  ///
  /// In en, this message translates to:
  /// **'Current price'**
  String get billingCurrentPrice;

  /// No description provided for @billingRenewalPeriod.
  ///
  /// In en, this message translates to:
  /// **'Renewal / period'**
  String get billingRenewalPeriod;

  /// No description provided for @billingDetailsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Billing details are not available yet.'**
  String get billingDetailsNotAvailable;

  /// No description provided for @billingManagementUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Billing management unavailable'**
  String get billingManagementUnavailable;

  /// No description provided for @billingOpenPortal.
  ///
  /// In en, this message translates to:
  /// **'Open billing portal'**
  String get billingOpenPortal;

  /// No description provided for @billingManagementUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Billing management is not available for this workspace yet. Subscription details will continue to appear here when provided by the server.'**
  String get billingManagementUnavailableMessage;

  /// No description provided for @billingManageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage your subscription with the billing portal.'**
  String get billingManageSubscription;

  /// No description provided for @billingWorkspacePlanManagement.
  ///
  /// In en, this message translates to:
  /// **'Workspace plan management'**
  String get billingWorkspacePlanManagement;

  /// No description provided for @billingWorkspacePlanDescActive.
  ///
  /// In en, this message translates to:
  /// **'Review current workspace limits and any upgrade or downgrade guidance.'**
  String get billingWorkspacePlanDescActive;

  /// No description provided for @billingWorkspacePlanDescSelect.
  ///
  /// In en, this message translates to:
  /// **'Select a workspace to review server-scoped billing limits and plan guidance.'**
  String get billingWorkspacePlanDescSelect;

  /// No description provided for @billingUsageSelectWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace plan requires a selected workspace'**
  String get billingUsageSelectWorkspace;

  /// No description provided for @billingUsageSelectWorkspaceMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a workspace to see current usage, plan limits, and upgrade guidance.'**
  String get billingUsageSelectWorkspaceMessage;

  /// No description provided for @billingUsageUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace usage unavailable'**
  String get billingUsageUnavailableTitle;

  /// No description provided for @billingUsageUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Usage details are unavailable right now.'**
  String get billingUsageUnavailableMessage;

  /// No description provided for @billingServerUsageAndLimits.
  ///
  /// In en, this message translates to:
  /// **'Server usage and limits'**
  String get billingServerUsageAndLimits;

  /// No description provided for @billingPlanDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plan details unavailable'**
  String get billingPlanDetailsUnavailable;

  /// No description provided for @billingMessageHistory.
  ///
  /// In en, this message translates to:
  /// **'Message history'**
  String get billingMessageHistory;

  /// No description provided for @billingPlanDowngraded.
  ///
  /// In en, this message translates to:
  /// **'Workspace plan downgraded'**
  String get billingPlanDowngraded;

  /// No description provided for @billingPlanDowngradedMessage.
  ///
  /// In en, this message translates to:
  /// **'This workspace plan was downgraded on {date}. Upgrade to restore higher limits.'**
  String billingPlanDowngradedMessage(String date);

  /// No description provided for @billingNeedMoreCapacity.
  ///
  /// In en, this message translates to:
  /// **'Need more capacity?'**
  String get billingNeedMoreCapacity;

  /// No description provided for @billingUpgradePortalMessage.
  ///
  /// In en, this message translates to:
  /// **'Open the billing portal to review upgrade options for this workspace plan.'**
  String get billingUpgradePortalMessage;

  /// No description provided for @billingUpgradeUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Upgrade options will appear here when billing management is available for this workspace.'**
  String get billingUpgradeUnavailableMessage;

  /// No description provided for @billingMessageHistoryUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get billingMessageHistoryUnlimited;

  /// No description provided for @billingMessageHistoryOneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get billingMessageHistoryOneDay;

  /// No description provided for @billingMessageHistoryDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String billingMessageHistoryDays(int count);

  /// No description provided for @threadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get threadsTitle;

  /// No description provided for @threadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No followed threads yet.'**
  String get threadsEmpty;

  /// No description provided for @threadsSwipeDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get threadsSwipeDone;

  /// No description provided for @threadsRepliesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} replies'**
  String threadsRepliesCount(int count);

  /// No description provided for @threadsUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String threadsUnreadCount(int count);

  /// No description provided for @threadsActionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open thread'**
  String get threadsActionOpen;

  /// No description provided for @threadsActionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get threadsActionDone;

  /// No description provided for @threadRepliesTitle.
  ///
  /// In en, this message translates to:
  /// **'Thread replies'**
  String get threadRepliesTitle;

  /// No description provided for @threadRepliesMissingContext.
  ///
  /// In en, this message translates to:
  /// **'Missing thread route context.'**
  String get threadRepliesMissingContext;

  /// No description provided for @threadRepliesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get threadRepliesRetry;

  /// No description provided for @threadRepliesFollowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Follow thread'**
  String get threadRepliesFollowTooltip;

  /// No description provided for @threadRepliesDoneTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mark thread done'**
  String get threadRepliesDoneTooltip;

  /// No description provided for @dmsSortAZ.
  ///
  /// In en, this message translates to:
  /// **'Sort A-Z'**
  String get dmsSortAZ;

  /// No description provided for @dmsSortRecent.
  ///
  /// In en, this message translates to:
  /// **'Sort by recent'**
  String get dmsSortRecent;

  /// No description provided for @dmsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get dmsMarkAllRead;

  /// No description provided for @dmsClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get dmsClearSearch;

  /// No description provided for @dmsMarkedUnread.
  ///
  /// In en, this message translates to:
  /// **'Marked as unread'**
  String get dmsMarkedUnread;

  /// No description provided for @dmsNewMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get dmsNewMessageTitle;

  /// No description provided for @dmsTabPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get dmsTabPeople;

  /// No description provided for @dmsTabAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get dmsTabAgents;

  /// No description provided for @dmsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get dmsSearchHint;

  /// No description provided for @dmsNoAgentsFound.
  ///
  /// In en, this message translates to:
  /// **'No agents found.'**
  String get dmsNoAgentsFound;

  /// No description provided for @dmsNoMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No members found.'**
  String get dmsNoMembersFound;

  /// No description provided for @dmsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dmsRetry;

  /// No description provided for @searchScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchScopeAll;

  /// No description provided for @searchScopeMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get searchScopeMessages;

  /// No description provided for @searchScopeChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get searchScopeChannels;

  /// No description provided for @searchScopeContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get searchScopeContacts;

  /// No description provided for @searchBadgeDm.
  ///
  /// In en, this message translates to:
  /// **'DM'**
  String get searchBadgeDm;

  /// No description provided for @searchBadgeChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get searchBadgeChannel;

  /// No description provided for @conversationFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get conversationFilesTitle;

  /// No description provided for @conversationFilesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get conversationFilesRetry;

  /// No description provided for @conversationFilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No files in this channel'**
  String get conversationFilesEmpty;

  /// No description provided for @conversationQuoteLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading message…'**
  String get conversationQuoteLoading;

  /// No description provided for @conversationQuoteNotFound.
  ///
  /// In en, this message translates to:
  /// **'Message not available'**
  String get conversationQuoteNotFound;

  /// No description provided for @conversationMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{member} other{members}}'**
  String conversationMemberCount(int count);

  /// No description provided for @conversationCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get conversationCloseSearch;

  /// No description provided for @conversationSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get conversationSearchTooltip;

  /// No description provided for @conversationInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Conversation info'**
  String get conversationInfoTooltip;

  /// No description provided for @conversationScreenshotTooltip.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get conversationScreenshotTooltip;

  /// No description provided for @conversationMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied. Please enable it in Settings.'**
  String get conversationMicDenied;

  /// No description provided for @conversationMicUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not start recording. Please check microphone availability.'**
  String get conversationMicUnavailable;

  /// No description provided for @conversationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load {title}.'**
  String conversationLoadFailed(String title);

  /// No description provided for @conversationRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get conversationRetry;

  /// No description provided for @conversationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages in {title} yet.'**
  String conversationEmpty(String title);

  /// No description provided for @conversationPresenceOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get conversationPresenceOnline;

  /// No description provided for @conversationPresenceIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get conversationPresenceIdle;

  /// No description provided for @conversationPresenceOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get conversationPresenceOffline;

  /// No description provided for @conversationOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Messages will be sent when you reconnect.'**
  String get conversationOfflineBanner;

  /// No description provided for @conversationInfoMute.
  ///
  /// In en, this message translates to:
  /// **'Mute Notifications'**
  String get conversationInfoMute;

  /// No description provided for @conversationInfoMuted.
  ///
  /// In en, this message translates to:
  /// **'Notifications are silenced'**
  String get conversationInfoMuted;

  /// No description provided for @conversationInfoUnmuted.
  ///
  /// In en, this message translates to:
  /// **'Receiving all notifications'**
  String get conversationInfoUnmuted;

  /// No description provided for @conversationInfoMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get conversationInfoMembers;

  /// No description provided for @conversationInfoFiles.
  ///
  /// In en, this message translates to:
  /// **'Shared files'**
  String get conversationInfoFiles;

  /// No description provided for @conversationInfoPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned messages'**
  String get conversationInfoPinned;

  /// No description provided for @conversationInfoProfileSection.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get conversationInfoProfileSection;

  /// No description provided for @conversationInfoDmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Direct message'**
  String get conversationInfoDmSubtitle;

  /// No description provided for @conversationPinnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned messages'**
  String get conversationPinnedTitle;

  /// No description provided for @conversationPinnedRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get conversationPinnedRetry;

  /// No description provided for @conversationPinnedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pinned messages'**
  String get conversationPinnedEmpty;

  /// No description provided for @conversationMessageAiBadge.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get conversationMessageAiBadge;

  /// No description provided for @conversationMessageReplyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{reply} other{replies}}'**
  String conversationMessageReplyCount(int count);

  /// No description provided for @conversationMessageInThread.
  ///
  /// In en, this message translates to:
  /// **'In thread'**
  String get conversationMessageInThread;

  /// No description provided for @conversationCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard.'**
  String get conversationCopiedToClipboard;

  /// No description provided for @conversationMessageForwarded.
  ///
  /// In en, this message translates to:
  /// **'Message forwarded'**
  String get conversationMessageForwarded;

  /// No description provided for @conversationSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send. Please try again.'**
  String get conversationSendFailed;

  /// No description provided for @conversationTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Task created.'**
  String get conversationTaskCreated;

  /// No description provided for @conversationQuoteFallback.
  ///
  /// In en, this message translates to:
  /// **'[Message]'**
  String get conversationQuoteFallback;

  /// No description provided for @conversationProfileMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get conversationProfileMessage;

  /// No description provided for @conversationSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search in conversation...'**
  String get conversationSearchHint;

  /// No description provided for @conversationSearchPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous result'**
  String get conversationSearchPrevious;

  /// No description provided for @conversationSearchNext.
  ///
  /// In en, this message translates to:
  /// **'Next result'**
  String get conversationSearchNext;

  /// No description provided for @conversationSearchClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get conversationSearchClose;

  /// No description provided for @conversationFormatBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get conversationFormatBold;

  /// No description provided for @conversationFormatItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get conversationFormatItalic;

  /// No description provided for @conversationFormatInlineCode.
  ///
  /// In en, this message translates to:
  /// **'Inline code'**
  String get conversationFormatInlineCode;

  /// No description provided for @conversationFormatCodeBlock.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get conversationFormatCodeBlock;

  /// No description provided for @conversationFormatLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get conversationFormatLink;

  /// No description provided for @conversationMessageListSemantics.
  ///
  /// In en, this message translates to:
  /// **'Message list'**
  String get conversationMessageListSemantics;

  /// No description provided for @membersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersTitle;

  /// No description provided for @membersRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Member?'**
  String get membersRemoveTitle;

  /// No description provided for @membersCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get membersCancel;

  /// No description provided for @membersRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get membersRemove;

  /// No description provided for @membersConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get membersConfirm;

  /// No description provided for @membersMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed.'**
  String membersMemberRemoved(String name);

  /// No description provided for @membersInviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied.'**
  String get membersInviteCopied;

  /// No description provided for @membersSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get membersSend;

  /// No description provided for @membersGenerateLink.
  ///
  /// In en, this message translates to:
  /// **'Generate Link'**
  String get membersGenerateLink;

  /// No description provided for @membersChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change Role'**
  String get membersChangeRole;

  /// No description provided for @membersRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get membersRoleAdmin;

  /// No description provided for @membersRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get membersRoleMember;

  /// No description provided for @membersMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get membersMakeAdmin;

  /// No description provided for @membersMakeMember.
  ///
  /// In en, this message translates to:
  /// **'Make member'**
  String get membersMakeMember;

  /// No description provided for @membersRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get membersRemoveMember;

  /// No description provided for @membersProfileMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get membersProfileMessage;

  /// No description provided for @savedMessagesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get savedMessagesRetry;

  /// No description provided for @biometricTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get biometricTryAgain;

  /// No description provided for @biometricDisableContinue.
  ///
  /// In en, this message translates to:
  /// **'Disable & Continue'**
  String get biometricDisableContinue;

  /// No description provided for @biometricSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get biometricSkipForNow;

  /// No description provided for @shareTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share to...'**
  String get shareTargetTitle;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed. Tap to retry.'**
  String get translationFailed;

  /// No description provided for @membersRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this server?'**
  String membersRemoveBody(String name);

  /// No description provided for @membersEmailValidationError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get membersEmailValidationError;

  /// No description provided for @membersInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Human'**
  String get membersInviteTitle;

  /// No description provided for @membersInviteEmailSection.
  ///
  /// In en, this message translates to:
  /// **'Send email invite'**
  String get membersInviteEmailSection;

  /// No description provided for @membersInviteEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get membersInviteEmailLabel;

  /// No description provided for @membersInviteEmailHint.
  ///
  /// In en, this message translates to:
  /// **'user@example.com'**
  String get membersInviteEmailHint;

  /// No description provided for @membersInviteLinkSection.
  ///
  /// In en, this message translates to:
  /// **'Or share invite link'**
  String get membersInviteLinkSection;

  /// No description provided for @membersInviteCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get membersInviteCopyLink;

  /// No description provided for @membersRoleAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Can manage members and invite'**
  String get membersRoleAdminSubtitle;

  /// No description provided for @membersRoleMemberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Standard workspace access'**
  String get membersRoleMemberSubtitle;

  /// No description provided for @savedMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedMessagesTitle;

  /// No description provided for @savedMessagesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved messages'**
  String get savedMessagesEmptyTitle;

  /// No description provided for @savedMessagesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long-press a message and tap \"Save\" to bookmark it.\nSaved messages appear here for quick reference.'**
  String get savedMessagesEmptySubtitle;

  /// No description provided for @savedMessagesUnsaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unsave'**
  String get savedMessagesUnsaveTooltip;

  /// No description provided for @savedMessagesSourceDm.
  ///
  /// In en, this message translates to:
  /// **'· DM'**
  String get savedMessagesSourceDm;

  /// No description provided for @savedMessagesSourceChannel.
  ///
  /// In en, this message translates to:
  /// **'· # {name}'**
  String savedMessagesSourceChannel(String name);

  /// No description provided for @biometricPrompt.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to continue using Slock'**
  String get biometricPrompt;

  /// No description provided for @biometricLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to continue'**
  String get biometricLockTitle;

  /// No description provided for @biometricLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to access Slock'**
  String get biometricLockSubtitle;

  /// No description provided for @biometricErrorLockout.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get biometricErrorLockout;

  /// No description provided for @biometricErrorPermanentLockout.
  ///
  /// In en, this message translates to:
  /// **'Biometrics locked. Please use your device passcode.'**
  String get biometricErrorPermanentLockout;

  /// No description provided for @biometricErrorNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics unavailable. Please try again.'**
  String get biometricErrorNotAvailable;

  /// No description provided for @biometricErrorNotEnrolled.
  ///
  /// In en, this message translates to:
  /// **'No biometrics enrolled. Please try again.'**
  String get biometricErrorNotEnrolled;

  /// No description provided for @biometricErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Try again ({count}/3).'**
  String biometricErrorGeneric(int count);

  /// No description provided for @shareSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search conversations...'**
  String get shareSearchHint;

  /// No description provided for @shareSectionChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get shareSectionChannels;

  /// No description provided for @shareSectionDirectMessages.
  ///
  /// In en, this message translates to:
  /// **'Direct Messages'**
  String get shareSectionDirectMessages;

  /// No description provided for @translationShowOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get translationShowOriginal;

  /// No description provided for @translationShowTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get translationShowTranslation;

  /// No description provided for @translationPending.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get translationPending;

  /// No description provided for @notificationPrefAllTitle.
  ///
  /// In en, this message translates to:
  /// **'All Messages'**
  String get notificationPrefAllTitle;

  /// No description provided for @notificationPrefAllDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications for all messages.'**
  String get notificationPrefAllDescription;

  /// No description provided for @notificationPrefMentionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Mentions & DMs Only'**
  String get notificationPrefMentionsTitle;

  /// No description provided for @notificationPrefMentionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Only receive notifications for direct messages.'**
  String get notificationPrefMentionsDescription;

  /// No description provided for @notificationPrefMuteTitle.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get notificationPrefMuteTitle;

  /// No description provided for @notificationPrefMuteDescription.
  ///
  /// In en, this message translates to:
  /// **'Do not show any foreground notifications.'**
  String get notificationPrefMuteDescription;

  /// No description provided for @membersInviteHumanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Invite human'**
  String get membersInviteHumanTooltip;

  /// No description provided for @membersErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Members unavailable'**
  String get membersErrorTitle;

  /// No description provided for @membersErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not load workspace members right now.'**
  String get membersErrorMessage;

  /// No description provided for @membersEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No members yet.'**
  String get membersEmptyMessage;

  /// No description provided for @membersInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invite email sent to {email}.'**
  String membersInviteSent(String email);

  /// No description provided for @membersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search members…'**
  String get membersSearchHint;

  /// No description provided for @membersSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No members match your search.'**
  String get membersSearchEmpty;

  /// No description provided for @membersSectionHumans.
  ///
  /// In en, this message translates to:
  /// **'Humans'**
  String get membersSectionHumans;

  /// No description provided for @membersSectionAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get membersSectionAgents;

  /// No description provided for @membersRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} is now {role}.'**
  String membersRoleChanged(String name, String role);

  /// No description provided for @membersRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get membersRoleOwner;

  /// No description provided for @homeSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeSearchTooltip;

  /// No description provided for @audioPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio playback failed'**
  String get audioPlaybackFailed;

  /// No description provided for @crashRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'App Recovered'**
  String get crashRecoveryTitle;

  /// No description provided for @crashRecoveryMessage.
  ///
  /// In en, this message translates to:
  /// **'The app stopped unexpectedly during your last session. You can export diagnostic logs to help us investigate.'**
  String get crashRecoveryMessage;

  /// No description provided for @crashRecoveryContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get crashRecoveryContinue;

  /// No description provided for @crashRecoveryExport.
  ///
  /// In en, this message translates to:
  /// **'Export Diagnostics'**
  String get crashRecoveryExport;

  /// No description provided for @filePreviewShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share file.'**
  String get filePreviewShareFailed;

  /// No description provided for @filePreviewShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get filePreviewShareTooltip;

  /// No description provided for @filePreviewOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'Open in external app'**
  String get filePreviewOpenExternal;

  /// No description provided for @filePreviewRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get filePreviewRetry;

  /// No description provided for @filePreviewOpenWith.
  ///
  /// In en, this message translates to:
  /// **'Open with…'**
  String get filePreviewOpenWith;

  /// No description provided for @annotationDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get annotationDraw;

  /// No description provided for @annotationText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get annotationText;

  /// No description provided for @annotationArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get annotationArrow;

  /// No description provided for @annotationUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get annotationUndo;

  /// No description provided for @annotationRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get annotationRedo;

  /// No description provided for @annotationColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get annotationColorRed;

  /// No description provided for @annotationColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get annotationColorGreen;

  /// No description provided for @annotationColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get annotationColorBlue;

  /// No description provided for @annotationColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get annotationColorYellow;

  /// No description provided for @annotationColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get annotationColorWhite;

  /// No description provided for @annotationColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get annotationColorBlack;

  /// No description provided for @voiceRecorderCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel recording'**
  String get voiceRecorderCancel;

  /// No description provided for @voiceRecorderSend.
  ///
  /// In en, this message translates to:
  /// **'Send voice message'**
  String get voiceRecorderSend;

  /// No description provided for @voiceMessageScrubber.
  ///
  /// In en, this message translates to:
  /// **'Voice message scrubber'**
  String get voiceMessageScrubber;

  /// No description provided for @voiceBubblePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get voiceBubblePause;

  /// No description provided for @voiceBubblePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get voiceBubblePlay;

  /// No description provided for @memberListItemMessageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get memberListItemMessageTooltip;

  /// No description provided for @memberListItemAdminActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Member admin actions'**
  String get memberListItemAdminActionsTooltip;

  /// No description provided for @homeOverviewSemantics.
  ///
  /// In en, this message translates to:
  /// **'Home overview'**
  String get homeOverviewSemantics;

  /// No description provided for @linkPreviewSemantics.
  ///
  /// In en, this message translates to:
  /// **'Link preview: {domain}'**
  String linkPreviewSemantics(String domain);

  /// No description provided for @textPreviewShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get textPreviewShowMore;

  /// No description provided for @textPreviewShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get textPreviewShowLess;

  /// No description provided for @profileAvatarEditSemantics.
  ///
  /// In en, this message translates to:
  /// **'Edit profile avatar'**
  String get profileAvatarEditSemantics;

  /// No description provided for @screenshotCanvasSemantics.
  ///
  /// In en, this message translates to:
  /// **'Screenshot annotation canvas'**
  String get screenshotCanvasSemantics;

  /// No description provided for @voiceWaveformSemantics.
  ///
  /// In en, this message translates to:
  /// **'Recording waveform'**
  String get voiceWaveformSemantics;

  /// No description provided for @unreadFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unreadFilterLabel;

  /// No description provided for @allFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilterLabel;

  /// No description provided for @agentEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit agent'**
  String get agentEditTooltip;

  /// No description provided for @agentDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete agent'**
  String get agentDeleteTooltip;

  /// No description provided for @searchClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClearTooltip;

  /// No description provided for @channelMembersAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get channelMembersAddTooltip;

  /// No description provided for @channelMembersRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get channelMembersRemoveTooltip;

  /// No description provided for @channelFilesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Channel files'**
  String get channelFilesTooltip;

  /// No description provided for @channelMembersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Channel members'**
  String get channelMembersTooltip;

  /// No description provided for @addHumanToChannelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to channel'**
  String get addHumanToChannelTooltip;

  /// No description provided for @addAgentToChannelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add agent to channel'**
  String get addAgentToChannelTooltip;

  /// No description provided for @togglePasswordVisibilityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle password visibility'**
  String get togglePasswordVisibilityTooltip;

  /// No description provided for @dismissAnnouncementTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissAnnouncementTooltip;

  /// No description provided for @shareTargetCancelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shareTargetCancelTooltip;

  /// No description provided for @dmAgentBadge.
  ///
  /// In en, this message translates to:
  /// **'AGENT'**
  String get dmAgentBadge;

  /// No description provided for @dmActionMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get dmActionMoveUp;

  /// No description provided for @dmActionMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get dmActionMoveDown;

  /// No description provided for @dmActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin conversation'**
  String get dmActionPin;

  /// No description provided for @dmActionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin conversation'**
  String get dmActionUnpin;

  /// No description provided for @dmActionMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as Unread'**
  String get dmActionMarkUnread;

  /// No description provided for @dmActionClose.
  ///
  /// In en, this message translates to:
  /// **'Close conversation'**
  String get dmActionClose;

  /// No description provided for @taskOverlayDropTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop to change status'**
  String get taskOverlayDropTitle;

  /// No description provided for @taskOverlayCancelHint.
  ///
  /// In en, this message translates to:
  /// **'Release outside boxes to cancel'**
  String get taskOverlayCancelHint;

  /// No description provided for @taskOverlayMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved to {status}'**
  String taskOverlayMovedTo(String status);

  /// No description provided for @taskOverlayCurrentBadge.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get taskOverlayCurrentBadge;

  /// No description provided for @taskOverlayReleaseHint.
  ///
  /// In en, this message translates to:
  /// **'Release to move here'**
  String get taskOverlayReleaseHint;

  /// No description provided for @taskStatusTodo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get taskStatusTodo;

  /// No description provided for @taskStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get taskStatusInProgress;

  /// No description provided for @taskStatusInReview.
  ///
  /// In en, this message translates to:
  /// **'In Review'**
  String get taskStatusInReview;

  /// No description provided for @taskStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStatusDone;

  /// No description provided for @taskStatusDescTodo.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get taskStatusDescTodo;

  /// No description provided for @taskStatusDescInProgress.
  ///
  /// In en, this message translates to:
  /// **'Working on it'**
  String get taskStatusDescInProgress;

  /// No description provided for @taskStatusDescInReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get taskStatusDescInReview;

  /// No description provided for @taskStatusDescDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskStatusDescDone;

  /// No description provided for @homeRetrySemantics.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetrySemantics;

  /// No description provided for @homeUnreadOverflowSemantics.
  ///
  /// In en, this message translates to:
  /// **'View all unread conversations'**
  String get homeUnreadOverflowSemantics;

  /// No description provided for @homeServerSwitcherSemantics.
  ///
  /// In en, this message translates to:
  /// **'Switch workspace'**
  String get homeServerSwitcherSemantics;

  /// No description provided for @unreadFilterToggleSemantics.
  ///
  /// In en, this message translates to:
  /// **'Toggle unread filter'**
  String get unreadFilterToggleSemantics;

  /// No description provided for @unreadListItemSemantics.
  ///
  /// In en, this message translates to:
  /// **'Open conversation: {title}'**
  String unreadListItemSemantics(String title);

  /// No description provided for @inboxItemSemantics.
  ///
  /// In en, this message translates to:
  /// **'Open notification'**
  String get inboxItemSemantics;

  /// No description provided for @inboxFilterTabSemantics.
  ///
  /// In en, this message translates to:
  /// **'Filter: {label}'**
  String inboxFilterTabSemantics(String label);

  /// No description provided for @searchScopeTabSemantics.
  ///
  /// In en, this message translates to:
  /// **'Search scope: {label}'**
  String searchScopeTabSemantics(String label);

  /// No description provided for @filePreviewDismissSemantics.
  ///
  /// In en, this message translates to:
  /// **'Swipe down to close'**
  String get filePreviewDismissSemantics;

  /// No description provided for @messageLinkChipSemantics.
  ///
  /// In en, this message translates to:
  /// **'Open link: {url}'**
  String messageLinkChipSemantics(String url);

  /// No description provided for @attachmentImageFallbackSemantics.
  ///
  /// In en, this message translates to:
  /// **'Image attachment'**
  String get attachmentImageFallbackSemantics;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
