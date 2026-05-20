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
  String get agentsNoMachineAssigned => 'Sin máquina asignada';

  @override
  String get releaseNotesTitle => 'Notas de versión';

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
  String get homeCardTasksUnavailable => 'Tareas no disponibles';

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

  @override
  String get refreshFailedSnackbar =>
      'No se pudo actualizar. Mostrando datos en cache.';

  @override
  String get refreshFailedRetry => 'Reintentar';

  @override
  String get workspaceSettingsUnavailableTitle =>
      'Configuración del espacio no disponible';

  @override
  String get workspaceSettingsUnavailableMessage =>
      'No se pudo cargar la configuración del espacio de trabajo.';

  @override
  String get workspaceSettingsNotFound => 'Espacio de trabajo no encontrado.';

  @override
  String get workspaceSettingsRoleLabel => 'Rol';

  @override
  String get workspaceSettingsRoleUnknown => 'Desconocido';

  @override
  String get workspaceSettingsCreatedLabel => 'Creado';

  @override
  String get workspaceSettingsManageSection => 'Gestionar';

  @override
  String get workspaceSettingsActionsSection => 'Acciones';

  @override
  String get workspaceSettingsRenameAction => 'Renombrar espacio de trabajo';

  @override
  String get workspaceSettingsDeleteAction => 'Eliminar espacio de trabajo';

  @override
  String get workspaceSettingsLeaveAction => 'Abandonar espacio de trabajo';

  @override
  String get workspaceSettingsRenamedSnackbar =>
      'Espacio de trabajo renombrado.';

  @override
  String get workspaceSettingsRenameFailed =>
      'Error al renombrar el espacio de trabajo.';

  @override
  String get workspaceSettingsDeleteDialogTitle =>
      '¿Eliminar espacio de trabajo?';

  @override
  String workspaceSettingsDeleteDialogMessage(String name) {
    return '¿Eliminar $name? Esto eliminará permanentemente el espacio de trabajo y todos sus datos.';
  }

  @override
  String get workspaceSettingsDeleteConfirmLabel => 'Eliminar';

  @override
  String get workspaceSettingsDeleteFailed =>
      'Error al eliminar el espacio de trabajo.';

  @override
  String get workspaceSettingsLeaveDialogTitle =>
      '¿Abandonar espacio de trabajo?';

  @override
  String workspaceSettingsLeaveDialogMessage(String name) {
    return '¿Abandonar $name? Puede volver a unirse con una nueva invitación.';
  }

  @override
  String get workspaceSettingsLeaveConfirmLabel => 'Abandonar';

  @override
  String get workspaceSettingsLeaveFailed =>
      'Error al abandonar el espacio de trabajo.';

  @override
  String get previewDeleted => 'Mensaje eliminado';

  @override
  String get previewSending => 'Enviando…';

  @override
  String get previewFailed => 'No enviado, toca para reintentar';

  @override
  String get previewSystem => 'Mensaje del sistema';

  @override
  String get previewLink => 'Enlace';

  @override
  String get previewVoice => 'Mensaje de voz';

  @override
  String get previewImage => 'Imagen';

  @override
  String get previewVideo => 'Video';

  @override
  String get previewFallback => 'Nuevo mensaje';

  @override
  String previewAttachment(String name) {
    return 'Adjunto: $name';
  }

  @override
  String get agentStatusThinking => 'Pensando';

  @override
  String get agentStatusWorking => 'Trabajando';

  @override
  String get agentStatusError => 'Error';

  @override
  String get agentStatusOnline => 'En línea';

  @override
  String get agentStatusOffline => 'Desconectado';

  @override
  String get agentStatusStopped => 'Detenido';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsAccountSection => 'Cuenta';

  @override
  String get settingsWorkspaceSection => 'Espacio de trabajo';

  @override
  String get settingsNotificationsSection => 'Notificaciones';

  @override
  String get settingsAppearanceSection => 'Apariencia';

  @override
  String get settingsLanguageSection => 'Idioma';

  @override
  String get settingsSecuritySection => 'Seguridad';

  @override
  String get settingsMoreSection => 'Más';

  @override
  String get settingsDangerZoneSection => 'Zona de peligro';

  @override
  String get settingsMyProfileTitle => 'Mi perfil';

  @override
  String get settingsMyProfileSubtitle => 'Revisa los detalles de tu cuenta.';

  @override
  String get settingsMembersTitle => 'Miembros';

  @override
  String get settingsMembersSubtitle => 'Ver y gestionar miembros del espacio.';

  @override
  String get settingsNotificationSettingsTitle =>
      'Configuración de notificaciones';

  @override
  String get settingsThemeTitle => 'Tema';

  @override
  String get settingsTranslationTitle => 'Traducción';

  @override
  String get settingsTranslationSubtitle =>
      'Idioma preferido y modo de traducción.';

  @override
  String get settingsBiometricLockTitle => 'Bloqueo biométrico';

  @override
  String get settingsBiometricLockEnabled =>
      'Activado — desbloquear con biometría tras inactividad';

  @override
  String get settingsBiometricLockDisabled =>
      'Desactivado — sin bloqueo biométrico';

  @override
  String get settingsBillingTitle => 'Facturación';

  @override
  String get settingsBillingSubtitle => 'Revisa el resumen de tu suscripción.';

  @override
  String get settingsReleaseNotesTitle => 'Notas de versión';

  @override
  String get settingsReleaseNotesSubtitle =>
      'Consulta las últimas actualizaciones del producto.';

  @override
  String get settingsDiagnosticsTitle => 'Diagnósticos';

  @override
  String get settingsDiagnosticsSubtitle =>
      'Ver y exportar registros de diagnóstico.';

  @override
  String get settingsLogOutTitle => 'Cerrar sesión';

  @override
  String get settingsLogOutSubtitle => 'Cerrar sesión en este dispositivo.';

  @override
  String get settingsLogOutDialogTitle => '¿Cerrar sesión?';

  @override
  String get settingsLogOutDialogContent =>
      'Se cerrará la sesión en este dispositivo.';

  @override
  String get settingsLogOutDialogCancel => 'Cancelar';

  @override
  String get settingsLogOutDialogConfirm => 'Cerrar sesión';

  @override
  String get settingsSignedInFallback => 'Sesión iniciada';

  @override
  String get settingsAccountUnavailable => 'Datos de cuenta no disponibles';

  @override
  String get settingsNotificationGranted => 'Concedido';

  @override
  String get settingsNotificationDenied => 'Denegado';

  @override
  String get settingsNotificationProvisional => 'Provisional';

  @override
  String get settingsNotificationNotRequested => 'No solicitado';

  @override
  String get notificationSettingsTitle => 'Configuración de notificaciones';

  @override
  String get notificationSettingsPermissionSection => 'Permiso';

  @override
  String get notificationSettingsPushNotifications => 'Notificaciones push';

  @override
  String get notificationSettingsFilterSection => 'Filtro de notificaciones';

  @override
  String get notificationSettingsDiagnosticsSection => 'Diagnósticos';

  @override
  String get notificationSettingsDeviceToken => 'Token del dispositivo';

  @override
  String get notificationSettingsPlatform => 'Plataforma';

  @override
  String get notificationSettingsLastRegistration => 'Último registro';

  @override
  String get notificationSettingsPermissionStatus => 'Estado del permiso';

  @override
  String get notificationSettingsRecentEvents => 'Eventos recientes';

  @override
  String get notificationSettingsNoEvents =>
      'No hay eventos de notificación recientes.';

  @override
  String get notificationSettingsNotAvailable => 'No disponible';

  @override
  String get notificationSettingsNotRegistered => 'Aún no registrado';

  @override
  String get notificationSettingsUpdateFailed =>
      'No se pudo actualizar la configuración de notificaciones.';

  @override
  String get notificationSettingsRefreshRegistration =>
      'Actualizar registro del dispositivo';

  @override
  String get notificationSettingsRetryAccess =>
      'Reintentar acceso a notificaciones';

  @override
  String get notificationSettingsEnable => 'Activar notificaciones push';

  @override
  String get notificationSettingsPermissionGranted => 'Permiso concedido';

  @override
  String get notificationSettingsPermissionDenied => 'Permiso denegado';

  @override
  String get notificationSettingsPermissionProvisional => 'Permiso provisional';

  @override
  String get notificationSettingsPermissionUnknown =>
      'Permiso no solicitado aún';

  @override
  String notificationSettingsDeviceRegistered(String date) {
    return 'Dispositivo registrado $date.';
  }

  @override
  String get notificationSettingsDeviceNotRegistered =>
      'Registro del dispositivo no disponible aún.';

  @override
  String get notificationSettingsResultGranted =>
      'Acceso a notificaciones concedido y registro del dispositivo actualizado.';

  @override
  String get notificationSettingsResultProvisional =>
      'Acceso a notificaciones provisional; registro del dispositivo actualizado.';

  @override
  String get notificationSettingsResultDenied =>
      'Acceso a notificaciones denegado.';

  @override
  String get notificationSettingsResultUnknown =>
      'El estado de notificaciones aún no está disponible en este dispositivo.';

  @override
  String get searchHintText => 'Buscar mensajes, canales o contactos...';

  @override
  String get searchIdleText =>
      'Escribe para buscar mensajes, canales o contactos.';

  @override
  String get searchNoResults => 'No se encontraron resultados.';

  @override
  String get searchRetry => 'Reintentar';

  @override
  String get searchFailedFallback => 'La búsqueda falló.';

  @override
  String get searchSectionChannels => 'Canales';

  @override
  String get searchSectionContacts => 'Contactos';

  @override
  String get searchSectionMessages => 'Mensajes';

  @override
  String get searchViewAll => 'Ver todo';

  @override
  String get searchLoadMore => 'Cargar más';

  @override
  String get searchFilterSender => 'Remitente';

  @override
  String get searchFilterChannel => 'Canal';

  @override
  String get searchFilterClear => 'Limpiar';

  @override
  String get searchFilterNewest => 'Más reciente';

  @override
  String get searchFilterOldest => 'Más antiguo';

  @override
  String get searchFilterBySenderTitle => 'Filtrar por remitente';

  @override
  String get searchFilterBySenderHint => 'Ingresa nombre del remitente…';

  @override
  String get searchFilterByChannelTitle => 'Filtrar por canal';

  @override
  String get searchFilterByChannelHint => 'Ingresa nombre del canal…';

  @override
  String get searchFilterCancel => 'Cancelar';

  @override
  String get searchFilterApply => 'Aplicar';

  @override
  String get searchCouldNotOpenConversation =>
      'No se pudo abrir la conversación.';

  @override
  String searchFilterFromPrefix(String name) {
    return 'De: $name';
  }

  @override
  String searchFilterInPrefix(String name) {
    return 'En: $name';
  }

  @override
  String get searchRecentTitle => 'Recientes';

  @override
  String get searchRecentClear => 'Borrar';

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
}
