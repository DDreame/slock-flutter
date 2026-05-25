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
