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

  /// No description provided for @homeCardChannels.
  ///
  /// In en, this message translates to:
  /// **'CHANNELS'**
  String get homeCardChannels;

  /// No description provided for @homeCardChannelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'active channels'**
  String get homeCardChannelsSubtitle;

  /// No description provided for @homeCardChannelsUnread.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String homeCardChannelsUnread(int count);

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

  /// No description provided for @homeCardThreads.
  ///
  /// In en, this message translates to:
  /// **'THREADS'**
  String get homeCardThreads;

  /// No description provided for @homeCardViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeCardViewAll;

  /// No description provided for @homeCardThreadsFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get homeCardThreadsFilterUnread;

  /// No description provided for @homeCardThreadsFilterRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get homeCardThreadsFilterRead;

  /// No description provided for @homeCardThreadsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get homeCardThreadsFilterAll;

  /// No description provided for @homeCardThreadsReplies.
  ///
  /// In en, this message translates to:
  /// **'{count} replies'**
  String homeCardThreadsReplies(int count);

  /// No description provided for @homeCardThreadsNew.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String homeCardThreadsNew(int count);

  /// No description provided for @homeCardThreadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No threads'**
  String get homeCardThreadsEmpty;

  /// No description provided for @homeCardAgentActivityIdle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get homeCardAgentActivityIdle;

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
