// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Slock';

  @override
  String get splashTitle => 'Slock';

  @override
  String get splashSubtitle => 'Preparando tu espacio de trabajo...';

  @override
  String get loginTitle => 'Iniciar sesion';

  @override
  String get loginEmailLabel => 'Correo electronico';

  @override
  String get loginPasswordLabel => 'Contrasena';

  @override
  String get loginSubmitLabel => 'Iniciar sesion';

  @override
  String get loginCreateAccountCta => 'Crear cuenta';

  @override
  String get loginForgotPasswordCta => 'Olvidaste tu contrasena?';

  @override
  String get loginEmailRequiredError => 'El correo electronico es obligatorio.';

  @override
  String get loginEmailInvalidError =>
      'Ingresa una direccion de correo electronico valida.';

  @override
  String get loginPasswordRequiredError => 'La contrasena es obligatoria.';

  @override
  String get loginFailedFallback =>
      'No se pudo iniciar sesion. Intentalo de nuevo.';

  @override
  String get registerTitle => 'Crear cuenta';

  @override
  String get registerDisplayNameLabel => 'Nombre visible';

  @override
  String get registerEmailLabel => 'Correo electronico';

  @override
  String get registerPasswordLabel => 'Contrasena';

  @override
  String get registerSubmitLabel => 'Crear cuenta';

  @override
  String get registerAlreadyHaveAccountCta =>
      'Ya tienes una cuenta? Inicia sesion';

  @override
  String get registerDisplayNameRequiredError =>
      'El nombre visible es obligatorio.';

  @override
  String get registerEmailRequiredError =>
      'El correo electronico es obligatorio.';

  @override
  String get registerEmailInvalidError =>
      'Ingresa una direccion de correo electronico valida.';

  @override
  String get registerPasswordTooShortError =>
      'La contrasena debe tener al menos 8 caracteres.';

  @override
  String get registerFailedFallback =>
      'No se pudo crear la cuenta. Intentalo de nuevo.';

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
  String get navChannels => 'Canales';

  @override
  String get navDms => 'Mensajes';

  @override
  String get navAgents => 'Agents';

  @override
  String get agentsNewTooltip => 'Nuevo agente';

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
  String get homeCardAgents => 'AGENTES';

  @override
  String get homeCardAgentsSubtitle => 'agentes en el espacio';

  @override
  String homeCardAgentsOnline(int count) {
    return '$count en linea';
  }

  @override
  String homeCardAgentsError(int count) {
    return '$count error';
  }

  @override
  String homeCardAgentsStopped(int count) {
    return '$count detenidos';
  }

  @override
  String get homeCardAgentsEmpty => 'Todos los agentes desconectados';

  @override
  String get homeCardTasks => 'TAREAS';

  @override
  String get homeCardTasksSubtitle => 'tareas totales';

  @override
  String get homeCardTasksEmpty => 'Sin tareas activas';

  @override
  String homeCardTasksOverflow(int count) {
    return '+$count más';
  }

  @override
  String get homeCardTasksInProgress => 'En progreso';

  @override
  String get homeCardTasksTodo => 'Pendiente';

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
  String get homeCardViewAll => 'Ver todo';

  @override
  String get homeCardAgentActivityOnline => 'en linea';

  @override
  String get homeCardAgentActivityThinking => 'pensando';

  @override
  String get homeCardAgentActivityWorking => 'trabajando';

  @override
  String get homeCardAgentActivityError => 'error';

  @override
  String get homeCardAgentActivityOffline => 'desconectado';

  @override
  String get homeCardTimeAgoNow => 'ahora';

  @override
  String homeCardTimeAgoMinutes(int count) {
    return 'hace ${count}m';
  }

  @override
  String homeCardTimeAgoHours(int count) {
    return 'hace ${count}h';
  }

  @override
  String homeCardTimeAgoDays(int count) {
    return 'hace ${count}d';
  }

  @override
  String get homeCardUnread => 'NO LEIDOS';

  @override
  String get homeCardUnreadEmpty => 'Todo al dia';

  @override
  String homeCardUnreadOverflow(int count) {
    return '+$count mas';
  }

  @override
  String homeCardUnreadBadge(int count) {
    return '$count';
  }

  @override
  String get homeCardUnreadMarkAllRead => 'Marcar todo como leido';

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
  String get channelsTabTitle => 'Canales';

  @override
  String get channelsTabPlaceholder =>
      'La lista de canales estara disponible pronto.';

  @override
  String get channelsTabSearchHint => 'Buscar canales';

  @override
  String get channelsTabEmpty => 'Aun no hay canales.';

  @override
  String get dmsTabTitle => 'Mensajes';

  @override
  String get dmsTabHeadline => 'Mensajes directos';

  @override
  String get dmsTabPlaceholder =>
      'Los mensajes directos estaran disponibles pronto.';

  @override
  String get dmsTabSearchHint => 'Buscar mensajes';

  @override
  String get dmsTabEmpty => 'Aun no hay mensajes directos.';

  @override
  String get settingsTooltip => 'Configuracion';

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
  String get baseUrlSettingsTitle => 'Configuracion del servidor';

  @override
  String get baseUrlSettingsSubtitle =>
      'Configura endpoints personalizados de API y WebSocket.';

  @override
  String get baseUrlApiLabel => 'URL base de API';

  @override
  String get baseUrlApiHint => 'https://api.example.com';

  @override
  String get baseUrlRealtimeLabel => 'URL de tiempo real';

  @override
  String get baseUrlRealtimeHint => 'wss://realtime.example.com';

  @override
  String get baseUrlSave => 'Guardar';

  @override
  String get baseUrlRestoreDefaults => 'Restaurar valores predeterminados';

  @override
  String get baseUrlTestConnection => 'Probar conexion';

  @override
  String get baseUrlTesting => 'Probando...';

  @override
  String get baseUrlSaved =>
      'Configuracion guardada. Reinicia la aplicacion para aplicar los cambios.';

  @override
  String get baseUrlRestored =>
      'Valores predeterminados restaurados. Reinicia la aplicacion para aplicar los cambios.';

  @override
  String get baseUrlApiInvalidError =>
      'Ingresa una URL valida con http:// o https://.';

  @override
  String get baseUrlRealtimeInvalidError =>
      'Ingresa una URL valida con ws://, wss://, http:// o https://.';

  @override
  String get baseUrlResultReachable => 'Accesible';

  @override
  String get baseUrlResultUnauthorized => 'Accesible (no autorizado)';

  @override
  String get baseUrlResultTimeout => 'Tiempo agotado';

  @override
  String get baseUrlResultInvalid => 'URL invalida';

  @override
  String get baseUrlEmptyDefault => 'Usando valor predeterminado';

  @override
  String get baseUrlRestartRequired =>
      'Se requiere reiniciar para aplicar los cambios.';

  @override
  String get baseUrlSettingsSettingsTile => 'Servidor';

  @override
  String get baseUrlSettingsSettingsTileSubtitle =>
      'Endpoints personalizados de API y WebSocket.';

  @override
  String get attachmentOpenInBrowser => 'Abrir en navegador';

  @override
  String get attachmentUnableToLoadImage => 'No se pudo cargar la imagen';

  @override
  String get attachmentHtmlOpensInBrowser => 'HTML · Abrir en navegador';
}
