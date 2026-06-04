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
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginEmailLabel => 'Correo electrónico';

  @override
  String get loginPasswordLabel => 'Contraseña';

  @override
  String get loginSubmitLabel => 'Iniciar sesión';

  @override
  String get loginCreateAccountCta => 'Crear cuenta';

  @override
  String get loginForgotPasswordCta => '¿Olvidaste tu contraseña?';

  @override
  String get loginEmailRequiredError => 'El correo electrónico es obligatorio.';

  @override
  String get loginEmailInvalidError =>
      'Ingresa una dirección de correo electrónico válida.';

  @override
  String get loginPasswordRequiredError => 'La contraseña es obligatoria.';

  @override
  String get registerTitle => 'Crear cuenta';

  @override
  String get registerDisplayNameLabel => 'Nombre visible';

  @override
  String get registerEmailLabel => 'Correo electrónico';

  @override
  String get registerPasswordLabel => 'Contraseña';

  @override
  String get registerSubmitLabel => 'Crear cuenta';

  @override
  String get registerAlreadyHaveAccountCta =>
      '¿Ya tienes una cuenta? Inicia sesión';

  @override
  String get registerDisplayNameRequiredError =>
      'El nombre visible es obligatorio.';

  @override
  String get registerEmailRequiredError =>
      'El correo electrónico es obligatorio.';

  @override
  String get registerEmailInvalidError =>
      'Ingresa una dirección de correo electrónico válida.';

  @override
  String get registerPasswordTooShortError =>
      'La contraseña debe tener al menos 8 caracteres.';

  @override
  String get forgotPasswordTitle => 'Olvidé mi contraseña';

  @override
  String get forgotPasswordSuccessTitle => 'Revisa tu correo';

  @override
  String get forgotPasswordSuccessMessage =>
      'Si ese correo está registrado, se ha enviado un enlace de restablecimiento. Revisa tu bandeja de entrada.';

  @override
  String get forgotPasswordEmailLabel => 'Correo electrónico';

  @override
  String get forgotPasswordSubmitLabel => 'Restablecer contraseña';

  @override
  String get forgotPasswordBackToLogin => 'Volver al inicio de sesión';

  @override
  String get forgotPasswordEmailRequiredError =>
      'El correo electrónico es obligatorio.';

  @override
  String get forgotPasswordEmailInvalidError =>
      'Ingresa una dirección de correo electrónico válida.';

  @override
  String get resetPasswordTitle => 'Restablecer contraseña';

  @override
  String get resetPasswordCompletedMessage =>
      'Contraseña restablecida. Ya puedes iniciar sesión con tu nueva contraseña.';

  @override
  String get resetPasswordNewPasswordLabel => 'Nueva contraseña';

  @override
  String get resetPasswordConfirmPasswordLabel => 'Confirmar nueva contraseña';

  @override
  String get resetPasswordSubmitLabel => 'Establecer nueva contraseña';

  @override
  String get resetPasswordBackToLogin => 'Volver al inicio de sesión';

  @override
  String get resetPasswordLinkInvalidError =>
      'El enlace de restablecimiento no es válido o ha expirado.';

  @override
  String get resetPasswordTooShortError =>
      'La contraseña debe tener al menos 8 caracteres.';

  @override
  String get resetPasswordMismatchError => 'Las contraseñas no coinciden.';

  @override
  String get verifyEmailTitle => 'Verificar correo electrónico';

  @override
  String get verifyEmailInstructions =>
      'Verifica tu correo electrónico para continuar.';

  @override
  String get verifyEmailResentMessage =>
      'Correo de verificación reenviado. Revisa tu bandeja de entrada.';

  @override
  String get verifyEmailResendButton => 'Reenviar correo de verificación';

  @override
  String get verifyEmailTokenLabel => 'Token de verificación';

  @override
  String get verifyEmailSubmitLabel => 'Verificar';

  @override
  String get verifyEmailSuccessMessage =>
      'Correo verificado. Ya puedes continuar a la aplicación.';

  @override
  String get verifyEmailContinueButton => 'Continuar a Slock';

  @override
  String get verifyEmailSignOut => 'Cerrar sesión';

  @override
  String get verifyEmailBackToLogin => 'Volver al inicio de sesión';

  @override
  String get verifyEmailTokenRequiredError =>
      'Ingresa un token de verificación.';

  @override
  String get navWorkspace => 'Inicio';

  @override
  String get navChannels => 'Canales';

  @override
  String get navDms => 'Mensajes';

  @override
  String get navAgents => 'Agentes';

  @override
  String get agentsNewTooltip => 'Nuevo agente';

  @override
  String get releaseNotesTitle => 'Notas de versión';

  @override
  String get homeConsoleMembers => 'Miembros';

  @override
  String get homeConsoleBilling => 'Facturación';

  @override
  String get homeConsoleWorkspaceSettings => 'Configuración del espacio';

  @override
  String get homeCardAgents => 'AGENTES';

  @override
  String get homeCardAgentsSubtitle => 'agentes en el espacio';

  @override
  String get homeCardAgentsEmpty => 'Todos los agentes desconectados';

  @override
  String get homeCardTasks => 'TAREAS';

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
    return '${count}min';
  }

  @override
  String homeCardTasksDurationHours(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String homeCardTasksDurationHoursOnly(int count) {
    return '${count}h';
  }

  @override
  String get homeCardViewAll => 'Ver todo';

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
  String get homeCardUnread => 'NO LEÍDOS';

  @override
  String get homeCardUnreadEmpty => 'Todo al día';

  @override
  String homeCardUnreadOverflow(int count) {
    return '+$count más';
  }

  @override
  String get homeCreateChannelTooltip => 'Crear canal';

  @override
  String get homeNewMessageTooltip => 'Nuevo mensaje';

  @override
  String homeHiddenConversationsCount(int count) {
    return 'Conversaciones ocultas ($count)';
  }

  @override
  String get homeHiddenConversationsTitle => 'Conversaciones ocultas';

  @override
  String get homeUnhide => 'Mostrar';

  @override
  String get homeNoServerMessage =>
      'Selecciona un espacio de trabajo para comenzar.';

  @override
  String get homeSelectWorkspace => 'Seleccionar espacio';

  @override
  String get homeLoadFailedFallback =>
      'No se pudieron cargar las conversaciones.';

  @override
  String get homeRetry => 'Reintentar';

  @override
  String get channelsTabTitle => 'Canales';

  @override
  String get channelsTabSearchHint => 'Buscar canales';

  @override
  String get channelsTabEmpty => 'Aún no hay canales.';

  @override
  String get channelsBrowseTooltip => 'Explorar canales';

  @override
  String get channelsBrowseTitle => 'Explorar canales';

  @override
  String get channelsBrowseEmpty => 'No hay canales disponibles para unirse.';

  @override
  String get channelsBrowseJoin => 'Unirse';

  @override
  String get channelsBrowseJoined => '¡Unido!';

  @override
  String get channelsBrowseJoinFailed => 'No se pudo unir al canal.';

  @override
  String get dmsTabTitle => 'Mensajes';

  @override
  String get dmsTabSearchHint => 'Buscar mensajes';

  @override
  String get dmsTabEmpty => 'Aún no hay mensajes directos.';

  @override
  String get settingsTooltip => 'Configuración';

  @override
  String get homeChannelCreated => 'Canal creado.';

  @override
  String get homeChannelUpdated => 'Canal actualizado.';

  @override
  String get homeDeleteChannelTitle => 'Eliminar canal';

  @override
  String homeDeleteChannelMessage(String name) {
    return '¿Eliminar $name? Esta acción no se puede deshacer.';
  }

  @override
  String get homeDeleteChannelConfirm => 'Eliminar';

  @override
  String get homeChannelDeleted => 'Canal eliminado.';

  @override
  String get homeLeaveChannelTitle => 'Abandonar canal';

  @override
  String homeLeaveChannelMessage(String name) {
    return '¿Abandonar $name?';
  }

  @override
  String get homeLeaveChannelConfirm => 'Abandonar';

  @override
  String get homeChannelLeft => 'Has abandonado el canal.';

  @override
  String get baseUrlSettingsTitle => 'Configuración del servidor';

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
  String get baseUrlTestConnection => 'Probar conexión';

  @override
  String get baseUrlTesting => 'Probando...';

  @override
  String get baseUrlSaved =>
      'Configuración guardada. Reinicia la aplicación para aplicar los cambios.';

  @override
  String get baseUrlRestored =>
      'Valores predeterminados restaurados. Reinicia la aplicación para aplicar los cambios.';

  @override
  String get baseUrlApiInvalidError =>
      'Ingresa una URL válida con http:// o https://.';

  @override
  String get baseUrlRealtimeInvalidError =>
      'Ingresa una URL válida con ws://, wss://, http:// o https://.';

  @override
  String get baseUrlResultReachable => 'Accesible';

  @override
  String get baseUrlResultUnauthorized => 'Accesible (no autorizado)';

  @override
  String get baseUrlResultTimeout => 'Tiempo agotado';

  @override
  String get baseUrlResultInvalid => 'URL inválida';

  @override
  String get baseUrlEmptyDefault => 'Usando valor predeterminado';

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
      'No se pudo actualizar. Mostrando datos en caché.';

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
  String get workspaceSettingsDeleteDialogTitle =>
      '¿Eliminar espacio de trabajo?';

  @override
  String workspaceSettingsDeleteDialogMessage(String name) {
    return '¿Eliminar $name? Esto eliminará permanentemente el espacio de trabajo y todos sus datos.';
  }

  @override
  String get workspaceSettingsDeleteConfirmLabel => 'Eliminar';

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
  String get workspaceSettingsOnboarding => 'Configuración de incorporación';

  @override
  String get onboardingSettingsTitle => 'Configuración de incorporación';

  @override
  String get onboardingSettingsDescription =>
      'Gestionar la experiencia de incorporación de nuevos miembros';

  @override
  String get onboardingSettingsSetupModalLabel =>
      'Mostrar recordatorio de configuración';

  @override
  String get onboardingSettingsSetupModalDescription =>
      'Mostrar recordatorio del asistente al unirse nuevos miembros';

  @override
  String get onboardingSettingsLoadError => 'Error al cargar la configuración';

  @override
  String get onboardingSettingsSaveError => 'Error al guardar la configuración';

  @override
  String get onboardingSettingsRetry => 'Reintentar';

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
  String get settingsBiometricLockTimeoutTitle => 'Tiempo de bloqueo';

  @override
  String get settingsBiometricLockTimeoutImmediate => 'Inmediatamente';

  @override
  String get settingsBiometricLockTimeoutOneMinute => 'Después de 1 minuto';

  @override
  String get settingsBiometricLockTimeoutFiveMinutes => 'Después de 5 minutos';

  @override
  String get settingsBiometricLockTimeoutFifteenMinutes =>
      'Después de 15 minutos';

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
  String get notificationSettingsDateRecently => 'recientemente';

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
  String get searchFilterDateAny => 'Cualquier momento';

  @override
  String get searchFilterDateToday => 'Hoy';

  @override
  String get searchFilterDateWeek => 'Última semana';

  @override
  String get searchFilterDateMonth => 'Último mes';

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
  String get machinesPageTitle => 'Máquinas';

  @override
  String get machinesAddButton => 'Agregar máquina';

  @override
  String get machinesLoadFailed => 'Error al cargar las máquinas.';

  @override
  String get machinesRegisterTitle => 'Registrar máquina';

  @override
  String get machinesRegisterAction => 'Registrar';

  @override
  String get machinesRegisterHelper =>
      'Crea una máquina y revela su clave API una sola vez.';

  @override
  String get machinesRegisteredTitle => 'Máquina registrada';

  @override
  String get machinesRenameTitle => 'Renombrar máquina';

  @override
  String get machinesRenameSaveAction => 'Guardar';

  @override
  String get machinesRenameHelper =>
      'Actualiza la etiqueta de la máquina visible en todo el espacio de trabajo.';

  @override
  String get machinesRenamedSnackbar => 'Máquina renombrada.';

  @override
  String get machinesRotatedApiKeyTitle => 'Clave API rotada';

  @override
  String get machinesDeleteTitle => '¿Eliminar máquina?';

  @override
  String get machinesDeleteCancel => 'Cancelar';

  @override
  String get machinesDeleteConfirm => 'Eliminar';

  @override
  String get machinesDeletedSnackbar => 'Máquina eliminada.';

  @override
  String get machinesApiKeyRevealedNote =>
      'Esta clave solo se muestra al momento de creación o rotación.';

  @override
  String get machinesApiKeyCopied => 'Clave API copiada.';

  @override
  String get machinesCopyButton => 'Copiar';

  @override
  String get machinesDoneButton => 'Listo';

  @override
  String get machinesRetryButton => 'Reintentar';

  @override
  String get machinesLatestDaemon => 'Último daemon';

  @override
  String get machinesEmptyTitle => 'Aún no hay máquinas registradas.';

  @override
  String get machinesEmptyDescription =>
      'Registra una máquina para vincular entornos de ejecución y operaciones de administración a este servidor.';

  @override
  String get machinesRegisterButton => 'Registrar máquina';

  @override
  String get machinesMenuRename => 'Renombrar';

  @override
  String get machinesMenuRotateApiKey => 'Rotar clave API';

  @override
  String get machinesMenuDelete => 'Eliminar';

  @override
  String get machinesMetaHost => 'Host';

  @override
  String get machinesMetaOs => 'SO';

  @override
  String get machinesMetaDaemon => 'Daemon';

  @override
  String get machinesStatusOnline => 'En línea';

  @override
  String get machinesStatusOffline => 'Desconectada';

  @override
  String get machinesStatusError => 'Error';

  @override
  String get machinesNameLabel => 'Nombre de la máquina';

  @override
  String get machinesNameDialogCancel => 'Cancelar';

  @override
  String machinesDeleteMessage(String name) {
    return '¿Eliminar $name? Esto quita la máquina de la lista del servidor.';
  }

  @override
  String machinesCopyApiKeyMessage(String name) {
    return 'Copia la clave API de $name ahora.';
  }

  @override
  String machinesSummaryCount(int count) {
    return '$count máquina(s)';
  }

  @override
  String machinesSummaryOnline(int count) {
    return '$count en línea';
  }

  @override
  String machinesApiKeyPrefix(String prefix) {
    return 'Clave $prefix...';
  }

  @override
  String get machinesMenuWorkspaces => 'Espacios de trabajo';

  @override
  String get workspacesPageTitle => 'Espacios de trabajo';

  @override
  String get workspacesEmpty => 'No hay espacios de trabajo en esta máquina.';

  @override
  String get workspacesLoadFailed => 'Error al cargar los espacios de trabajo.';

  @override
  String get workspacesRetryButton => 'Reintentar';

  @override
  String get workspacesDeleteTitle => '¿Eliminar espacio de trabajo?';

  @override
  String workspacesDeleteMessage(String name) {
    return '¿Eliminar el espacio de trabajo \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get workspacesDeleteCancel => 'Cancelar';

  @override
  String get workspacesDeleteConfirm => 'Eliminar';

  @override
  String get workspacesDeletedSnackbar => 'Espacio de trabajo eliminado.';

  @override
  String get workspacesMetaPath => 'Ruta';

  @override
  String get workspacesStatusActive => 'Activo';

  @override
  String get workspacesStatusInactive => 'Inactivo';

  @override
  String get tasksLoadFailed => 'Error al cargar las tareas.';

  @override
  String get tasksEmptyAll => 'Aún no hay tareas.';

  @override
  String get tasksNoChannelsAvailable => 'No hay canales disponibles.';

  @override
  String get tasksCreatedSnackbar => 'Tarea creada.';

  @override
  String get tasksRetryAction => 'REINTENTAR';

  @override
  String get tasksDeleteTitle => '¿Eliminar tarea?';

  @override
  String tasksDeleteMessage(String title) {
    return '¿Eliminar \"$title\"? Esta acción no se puede deshacer.';
  }

  @override
  String get tasksDeleteCancel => 'Cancelar';

  @override
  String get tasksDeleteConfirm => 'Eliminar';

  @override
  String get tasksDeletedSnackbar => 'Tarea eliminada.';

  @override
  String get tasksHeaderTitle => 'Tareas';

  @override
  String get tasksNewButton => 'Nueva';

  @override
  String get tasksSummaryTodo => 'Por hacer';

  @override
  String get tasksSummaryInProgress => 'En progreso';

  @override
  String get tasksSummaryReview => 'Revisión';

  @override
  String get tasksSummaryDone => 'Completadas';

  @override
  String get tasksSummaryClosed => 'Cerradas';

  @override
  String get tasksEmptyChannel => 'No hay tareas en este canal.';

  @override
  String get tasksFilterAll => 'Todas';

  @override
  String get tasksSectionTodo => 'Por hacer';

  @override
  String get tasksSectionInProgress => 'En progreso';

  @override
  String get tasksSectionInReview => 'En revisión';

  @override
  String get tasksSectionDone => 'Completadas';

  @override
  String get tasksSectionClosed => 'Cerradas';

  @override
  String get tasksActionsTooltip => 'Acciones de tarea';

  @override
  String get tasksSwipeDone => 'Completada';

  @override
  String get tasksActionMarkDone => 'Marcar como completada';

  @override
  String get tasksActionClose => 'Cerrar tarea';

  @override
  String get tasksActionStart => 'Iniciar';

  @override
  String get tasksActionMoveToReview => 'Mover a revisión';

  @override
  String get tasksActionReopen => 'Reabrir';

  @override
  String get tasksActionRevertInProgress => 'Revertir a En progreso';

  @override
  String get tasksActionRevertTodo => 'Revertir a Por hacer';

  @override
  String get tasksActionClaim => 'Reclamar';

  @override
  String get tasksActionUnclaim => 'Liberar';

  @override
  String get tasksActionDelete => 'Eliminar';

  @override
  String get tasksRetryButton => 'Reintentar';

  @override
  String get tasksCreateTitle => 'Crear tarea';

  @override
  String get tasksCreateChannelLabel => 'Canal';

  @override
  String get tasksCreateTitleLabel => 'Título';

  @override
  String get tasksCreateCancel => 'Cancelar';

  @override
  String get tasksCreateConfirm => 'Crear';

  @override
  String get tasksAccessibilityTodo => 'Por hacer';

  @override
  String get tasksAccessibilityInProgress => 'En progreso';

  @override
  String get tasksAccessibilityInReview => 'En revisión';

  @override
  String get tasksAccessibilityDone => 'Completada';

  @override
  String get tasksAccessibilityClosed => 'Cancelada';

  @override
  String get screenshotAnnotateNoCapture => 'No se capturó ninguna pantalla';

  @override
  String get screenshotAnnotateDiscardTooltip => 'Descartar';

  @override
  String get screenshotAnnotateTitle => 'Anotar captura de pantalla';

  @override
  String get screenshotAnnotateSaveTooltip => 'Guardar en dispositivo';

  @override
  String get screenshotAnnotateShareTooltip => 'Compartir';

  @override
  String get screenshotAnnotateAddTextTitle => 'Agregar texto';

  @override
  String get screenshotAnnotateTextHint => 'Ingresa texto...';

  @override
  String get screenshotAnnotateCancel => 'Cancelar';

  @override
  String get screenshotAnnotateAddButton => 'Agregar';

  @override
  String get screenshotAnnotateExportFailed => 'Error al exportar la captura';

  @override
  String screenshotAnnotateExportError(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String screenshotAnnotateSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get screenshotAnnotateShareSubject => 'Captura de pantalla';

  @override
  String get dateSeparatorToday => 'Hoy';

  @override
  String get dateSeparatorYesterday => 'Ayer';

  @override
  String get conversationComposerHint => 'Escribe un mensaje';

  @override
  String get conversationComposerAttachPhotoVideo => 'Foto y video';

  @override
  String get conversationComposerAttachCamera => 'Cámara';

  @override
  String get conversationComposerAttachFile => 'Archivo';

  @override
  String get conversationComposerSendFailedFallback =>
      'No se pudo enviar el mensaje.';

  @override
  String get conversationComposerAttachTooltip => 'Adjuntar archivo';

  @override
  String get conversationComposerFormattingTooltip => 'Formato';

  @override
  String get conversationComposerEmojiTooltip => 'Emoji';

  @override
  String get conversationComposerTaskToggleTooltip => 'Enviar como tarea';

  @override
  String get conversationComposerOverflowTooltip => 'Más opciones';

  @override
  String get conversationComposerCameraUnavailable =>
      'Cámara no disponible. Comprueba los permisos.';

  @override
  String get conversationContextEditMessage => 'Editar mensaje';

  @override
  String get conversationContextReply => 'Responder';

  @override
  String get conversationContextSelect => 'Seleccionar';

  @override
  String get conversationContextReact => 'Reaccionar';

  @override
  String get conversationContextTranslate => 'Traducir';

  @override
  String get conversationContextCopyText => 'Copiar texto';

  @override
  String get conversationContextCopyMarkdown => 'Copiar markdown';

  @override
  String get conversationContextCopyLink => 'Copiar enlace';

  @override
  String get conversationContextForward => 'Reenviar';

  @override
  String get conversationContextSaveMessage => 'Guardar mensaje';

  @override
  String get conversationContextUnsaveMessage => 'Quitar guardado';

  @override
  String get conversationContextPinMessage => 'Fijar mensaje';

  @override
  String get conversationContextUnpinMessage => 'Desfijar mensaje';

  @override
  String get conversationContextReplyInThread => 'Responder en hilo';

  @override
  String get conversationContextCreateTask => 'Crear tarea';

  @override
  String get conversationContextDeleteMessage => 'Eliminar mensaje';

  @override
  String get conversationSelectionCancel => 'Cancelar';

  @override
  String get conversationSelectionSave => 'Guardar';

  @override
  String get conversationSelectionExportAsImage => 'Exportar como imagen';

  @override
  String get conversationSelectionSaveToGallery => 'Guardar en galería';

  @override
  String get conversationSelectionSavedToGallery => 'Guardado en galería';

  @override
  String get conversationSelectionSaveGalleryFailed =>
      'No se pudo guardar — revise los permisos de almacenamiento';

  @override
  String conversationExportThreadReplies(int count) {
    return 'Contiene $count respuestas';
  }

  @override
  String get conversationSelectionDelete => 'Eliminar';

  @override
  String conversationSelectionSelected(int count) {
    return '$count seleccionados';
  }

  @override
  String conversationSelectionBatchSucceeded(int count, String action) {
    return '$count $action.';
  }

  @override
  String conversationSelectionBatchFailed(String action, int count) {
    return 'No se pudo $action $count mensaje(s).';
  }

  @override
  String conversationSelectionBatchPartial(
      int succeeded, String action, int failed) {
    return '$succeeded $action, $failed fallidos.';
  }

  @override
  String get conversationSelectionActionSaveVerb => 'guardar';

  @override
  String get conversationSelectionActionSaved => 'guardados';

  @override
  String get conversationSelectionActionDeleteVerb => 'eliminar';

  @override
  String get conversationSelectionActionDeleted => 'eliminados';

  @override
  String get conversationEditDialogTitle => 'Editar mensaje';

  @override
  String get conversationEditDialogCancel => 'Cancelar';

  @override
  String get conversationEditDialogSave => 'Guardar';

  @override
  String get conversationEditSuccess => 'Mensaje editado.';

  @override
  String get conversationEditFailedFallback => 'No se pudo editar el mensaje.';

  @override
  String get conversationMessageDeletedPlaceholder => '[Mensaje eliminado]';

  @override
  String get conversationReactWithEmojiTitle => 'Reaccionar con emoji';

  @override
  String conversationReactWithEmojiSemantics(String emoji) {
    return 'Reaccionar con $emoji';
  }

  @override
  String get conversationDeleteDialogTitle => '¿Eliminar mensaje?';

  @override
  String get conversationDeleteDialogContent =>
      'Este mensaje se eliminará permanentemente.';

  @override
  String get conversationDeleteDialogCancel => 'Cancelar';

  @override
  String get conversationDeleteDialogConfirm => 'Eliminar';

  @override
  String get conversationDeleteSuccess => 'Mensaje eliminado.';

  @override
  String get conversationOpenLinkTitle => 'Abrir enlace';

  @override
  String conversationOpenLinkContent(String url) {
    return '¿Abrir $url?';
  }

  @override
  String get conversationOpenLinkCancel => 'Cancelar';

  @override
  String get conversationOpenLinkConfirm => 'Abrir';

  @override
  String get conversationMessageActionsSemantics => 'Acciones del mensaje';

  @override
  String get conversationShowMessageMenuSemantics => 'Mostrar menú del mensaje';

  @override
  String get conversationReplySemantics => 'Responder';

  @override
  String get conversationSwipeLeftSemantics => 'Entrar al hilo';

  @override
  String get conversationSwipeRightReactionSemantics => 'Agregar reacción';

  @override
  String get channelStopAllAgents => 'Detener todos los agentes';

  @override
  String get channelResumeAllAgents => 'Reanudar todos los agentes';

  @override
  String get channelStopAllAgentsTitle => 'Detener todos los agentes';

  @override
  String get channelStopAllAgentsMessage =>
      '¿Detener todos los agentes en este canal? No responderán hasta que se reanuden.';

  @override
  String get channelStopAllAgentsConfirm => 'Detener todos';

  @override
  String get channelStopAllAgentsSuccess => 'Todos los agentes detenidos.';

  @override
  String get channelStopAllAgentsFailed => 'Error al detener los agentes.';

  @override
  String get channelResumeAllAgentsSuccess => 'Todos los agentes reanudados.';

  @override
  String get channelResumeAllAgentsFailed => 'Error al reanudar los agentes.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get errorNetwork =>
      'Error de red. Verifica tu conexión e intenta de nuevo.';

  @override
  String get errorTimeout => 'Tiempo de espera agotado. Intenta de nuevo.';

  @override
  String get errorUnauthorized => 'Sesión expirada. Inicia sesión de nuevo.';

  @override
  String get errorForbidden => 'No tienes permiso para realizar esta acción.';

  @override
  String get errorNotFound => 'El recurso solicitado no fue encontrado.';

  @override
  String get errorConflict =>
      'Ocurrió un conflicto. Actualiza e intenta de nuevo.';

  @override
  String get errorValidation =>
      'Entrada no válida. Verifica e intenta de nuevo.';

  @override
  String get errorRateLimit =>
      'Demasiadas solicitudes. Espera un momento e intenta de nuevo.';

  @override
  String get errorServer => 'Error del servidor. Intenta más tarde.';

  @override
  String get errorCancelled => 'Solicitud cancelada.';

  @override
  String get errorUnknown => 'Algo salió mal. Intenta de nuevo.';

  @override
  String get pendingNewMessages => 'Mensajes nuevos';

  @override
  String get pendingSending => 'Enviando...';

  @override
  String get pendingQueued => 'En cola — esperando conexión';

  @override
  String get pendingSent => 'Enviado';

  @override
  String get pendingFailedToSend => 'Error al enviar';

  @override
  String get pendingRetry => 'Reintentar';

  @override
  String get pendingDismiss => 'Descartar';

  @override
  String get pendingEarlierHistoryLimited =>
      'El historial anterior es limitado.';

  @override
  String get composerSendTooltip => 'Enviar';

  @override
  String get composerVoiceMessageTooltip => 'Mensaje de voz';

  @override
  String get composerFileTooLarge =>
      'Archivo demasiado grande. Tamaño máximo: 50 MB';

  @override
  String get messageSenderYou => 'Tú';

  @override
  String get channelActionMoveUp => 'Mover arriba';

  @override
  String get channelActionMoveDown => 'Mover abajo';

  @override
  String get channelActionPin => 'Fijar canal';

  @override
  String get channelActionUnpin => 'Desfijar canal';

  @override
  String get channelActionMarkUnread => 'Marcar como no leído';

  @override
  String get channelActionEdit => 'Editar canal';

  @override
  String get channelActionLeave => 'Salir del canal';

  @override
  String get channelActionDelete => 'Eliminar canal';

  @override
  String get channelsSortAlphabetical => 'Ordenar A-Z';

  @override
  String get channelsSortRecent => 'Ordenar por reciente';

  @override
  String get channelsMarkAllRead => 'Marcar todo como leído';

  @override
  String get channelsClearSearch => 'Borrar búsqueda';

  @override
  String get channelsMarkedUnread => 'Marcado como no leído';

  @override
  String get channelsCreateTitle => 'Nuevo canal';

  @override
  String get channelsCreateSectionName => 'NOMBRE DEL CANAL';

  @override
  String get channelsCreateNameHint => 'nombre-del-canal';

  @override
  String get channelsCreateSectionDescription => 'DESCRIPCIÓN (OPCIONAL)';

  @override
  String get channelsCreateDescriptionHint => '¿De qué trata este canal?';

  @override
  String get channelsCreateSectionVisibility => 'VISIBILIDAD';

  @override
  String get channelsCreateSubmitting => 'Creando...';

  @override
  String get channelsCreateSubmit => 'Crear canal';

  @override
  String get channelsCreateNoServer =>
      'No se ha seleccionado un servidor activo.';

  @override
  String get channelsCreateVisibilityPublic => 'Público';

  @override
  String get channelsCreateVisibilityPublicSub => 'Visible para todos';

  @override
  String get channelsCreateVisibilityPrivate => 'Privado';

  @override
  String get channelsCreateVisibilityPrivateSub => 'Solo por invitación';

  @override
  String get channelsMembersTitle => 'Miembros del canal';

  @override
  String get channelsMembersRetry => 'Reintentar';

  @override
  String get channelsMembersEmpty => 'No hay miembros en este canal.';

  @override
  String get channelsMembersTypeAgent => 'Agente';

  @override
  String get channelsMembersTypeHuman => 'Humano';

  @override
  String get channelsMembersMessageTooltip => 'Mensaje';

  @override
  String get channelsMembersRemoveTitle => '¿Eliminar miembro?';

  @override
  String channelsMembersRemoveMessage(String name) {
    return '¿Eliminar a $name de este canal?';
  }

  @override
  String get channelsMembersRemoveCancel => 'Cancelar';

  @override
  String get channelsMembersRemoveConfirm => 'Eliminar';

  @override
  String get channelsAddMemberTitle => 'Añadir miembro';

  @override
  String get channelsAddMemberTabHumans => 'Humanos';

  @override
  String get channelsAddMemberTabAgents => 'Agentes';

  @override
  String get channelsAddMemberClose => 'Cerrar';

  @override
  String get channelsAddMemberNoHumans => 'No hay más humanos para añadir.';

  @override
  String get channelsAddMemberNoAgents => 'No hay más agentes para añadir.';

  @override
  String get channelsDialogCreateTitle => 'Crear canal';

  @override
  String get channelsDialogCreateNameLabel => 'Nombre del canal';

  @override
  String get channelsDialogCreateCancel => 'Cancelar';

  @override
  String get channelsDialogCreateSubmitting => 'Creando...';

  @override
  String get channelsDialogCreateSubmit => 'Crear';

  @override
  String get channelsDialogEditTitle => 'Editar canal';

  @override
  String get channelsDialogEditNameLabel => 'Nombre del canal';

  @override
  String get channelsDialogEditDescriptionLabel => 'Descripción';

  @override
  String get channelsDialogEditDescriptionHint => '¿De qué trata este canal?';

  @override
  String get channelsDialogEditPrivateLabel => 'Canal privado';

  @override
  String get channelsDialogEditPrivateDescription =>
      'Solo los miembros invitados pueden acceder';

  @override
  String get channelsDialogEditCancel => 'Cancelar';

  @override
  String get channelsDialogEditSubmitting => 'Guardando...';

  @override
  String get channelsDialogEditSubmit => 'Guardar';

  @override
  String get channelsDialogConfirmCancel => 'Cancelar';

  @override
  String get channelsDialogConfirmWorking => 'Procesando...';

  @override
  String get serversInviteTitle => 'Unirse al espacio de trabajo';

  @override
  String get serversInviteJoining => 'Uniéndose al espacio de trabajo...';

  @override
  String get serversInviteFailedFallback =>
      'Error al unirse al espacio de trabajo.';

  @override
  String get serversInviteRetry => 'Reintentar';

  @override
  String get serversInviteGoHome => 'Ir al inicio';

  @override
  String get serversInviteDescription =>
      'Has sido invitado a unirte a un espacio de trabajo.';

  @override
  String get serversInviteAccept => 'Unirse al espacio de trabajo';

  @override
  String get serversInviteCancel => 'Cancelar';

  @override
  String serversInviteSuccessNamed(String name) {
    return '¡Te uniste a $name!';
  }

  @override
  String get serversInviteSuccessGeneric => '¡Te uniste al espacio de trabajo!';

  @override
  String get serversInviteContinue => 'Continuar';

  @override
  String get serversInvitePreviewLoading => 'Cargando...';

  @override
  String get serversInvitePreviewDescription =>
      'Has sido invitado a unirte a este espacio';

  @override
  String serversInvitePreviewMembers(int count) {
    return '$count miembros';
  }

  @override
  String get serversInvitePreviewExpired =>
      'La invitación ha expirado o no es válida';

  @override
  String get serversInvitePreviewRateLimit =>
      'Demasiadas solicitudes, inténtalo más tarde';

  @override
  String get serversDialogCreateTitle => 'Crear espacio de trabajo';

  @override
  String get serversDialogCreateNameLabel => 'Nombre del espacio de trabajo';

  @override
  String get serversDialogCreateCancel => 'Cancelar';

  @override
  String get serversDialogCreateSubmit => 'Crear';

  @override
  String get serversDialogRenameTitle => 'Renombrar espacio de trabajo';

  @override
  String get serversDialogRenameNameLabel => 'Nombre del espacio de trabajo';

  @override
  String get serversDialogRenameCancel => 'Cancelar';

  @override
  String get serversDialogRenameSubmit => 'Guardar';

  @override
  String get serversDialogJoinTitle => 'Unirse al espacio de trabajo';

  @override
  String get serversDialogJoinLabel => 'Código de invitación o enlace';

  @override
  String get serversDialogJoinHint => 'https://slock.ai/invite/token-123';

  @override
  String get serversDialogJoinCancel => 'Cancelar';

  @override
  String get serversDialogJoinSubmit => 'Unirse';

  @override
  String get serversDialogConfirmCancel => 'Cancelar';

  @override
  String get serversSwitcherTitle => 'Cambiar espacio de trabajo';

  @override
  String get serversSwitcherCreating => 'Creando...';

  @override
  String get serversSwitcherCreateAction => 'Crear espacio de trabajo';

  @override
  String get serversSwitcherJoining => 'Uniéndose...';

  @override
  String get serversSwitcherJoinAction => 'Unirse al espacio de trabajo';

  @override
  String get serversSwitcherEmpty => 'No hay espacios de trabajo disponibles.';

  @override
  String get serversSwitcherSettings => 'Configuración del espacio de trabajo';

  @override
  String get serversSwitcherCreatedSnackbar => 'Espacio de trabajo creado.';

  @override
  String get serversSwitcherJoinedSnackbar =>
      'Te uniste al espacio de trabajo.';

  @override
  String get serversSwitcherDeleteTitle => '¿Eliminar espacio de trabajo?';

  @override
  String serversSwitcherDeleteMessage(String name) {
    return '¿Eliminar $name? Esto eliminará permanentemente el espacio de trabajo.';
  }

  @override
  String get serversSwitcherDeleteConfirm => 'Eliminar';

  @override
  String get serversSwitcherDeletedSnackbar => 'Espacio de trabajo eliminado.';

  @override
  String get serversSwitcherLeaveTitle => '¿Salir del espacio de trabajo?';

  @override
  String serversSwitcherLeaveMessage(String name) {
    return '¿Salir de $name? Puedes volver a unirte más tarde con una nueva invitación.';
  }

  @override
  String get serversSwitcherLeaveConfirm => 'Salir';

  @override
  String get serversSwitcherLeftSnackbar => 'Saliste del espacio de trabajo.';

  @override
  String get serversSwitcherRenamedSnackbar => 'Espacio de trabajo renombrado.';

  @override
  String get serversSwitcherRowRename => 'Renombrar';

  @override
  String get serversSwitcherRowDelete => 'Eliminar espacio de trabajo';

  @override
  String get serversSwitcherRowLeave => 'Salir del espacio de trabajo';

  @override
  String get serversSwitcherRetry => 'Reintentar';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido a Slock';

  @override
  String get onboardingBack => 'Atrás';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingFinish => 'Finalizar';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingSetupTitle => 'Configura tu espacio de trabajo';

  @override
  String get onboardingSetupBody =>
      'Slock está listo. Tómate un momento para configurar las notificaciones y tu perfil antes de comenzar.';

  @override
  String get onboardingNotificationsTitle => 'Mantente al día';

  @override
  String get onboardingNotificationsBody =>
      'Activa las notificaciones para que las menciones, respuestas y tareas te lleguen rápidamente.';

  @override
  String get onboardingNotificationsButton => 'Activar notificaciones';

  @override
  String get onboardingProfileTitle => 'Completa tu perfil';

  @override
  String get onboardingProfileBody =>
      'Agrega tu nombre, biografía o avatar para que tus compañeros te reconozcan.';

  @override
  String get onboardingProfileButton => 'Editar perfil';

  @override
  String get agentsEmptyTitle => 'Aún no hay agentes.';

  @override
  String get agentsSelectServerFirst => 'Selecciona un servidor primero.';

  @override
  String get agentsCreated => 'Agente creado.';

  @override
  String get agentsUpdated => 'Agente actualizado.';

  @override
  String get agentsDeleted => 'Agente eliminado.';

  @override
  String get agentsResetSuccess => 'Agente reiniciado.';

  @override
  String get agentsDeleteTitle => '¿Eliminar agente?';

  @override
  String agentsDeleteMessage(String name) {
    return '¿Eliminar $name? Esto eliminará la configuración del agente del espacio de trabajo.';
  }

  @override
  String get agentsStopTitle => '¿Detener agente?';

  @override
  String agentsStopMessage(String name) {
    return '¿Detener $name? El agente terminará su acción actual antes de detenerse.';
  }

  @override
  String get agentsResetTitle => '¿Reiniciar sesión?';

  @override
  String agentsResetMessage(String name) {
    return '¿Reiniciar $name? Esto borrará el historial de conversación del agente.';
  }

  @override
  String agentsSummary(int active, int stopped) {
    return '$active activos / $stopped detenidos';
  }

  @override
  String get agentsActionStart => 'Iniciar';

  @override
  String get agentsActionStop => 'Detener';

  @override
  String get agentsActionReset => 'Reiniciar';

  @override
  String get agentsActionResetSession => 'Reiniciar sesión';

  @override
  String get agentsActionMessage => 'Mensaje';

  @override
  String get agentsActionDelete => 'Eliminar';

  @override
  String get agentsActionCancel => 'Cancelar';

  @override
  String get agentsAppBarTitle => 'Agente';

  @override
  String get agentsFailedToLoad => 'Error al cargar agentes.';

  @override
  String get agentsNotFound => 'Agente no encontrado.';

  @override
  String get agentsActivityLogTitle => 'Registro de actividad';

  @override
  String get agentsActivityLogEmpty =>
      'Sin entradas en el registro de actividad.';

  @override
  String get agentsActivityLogLoadFailed =>
      'Error al cargar el registro de actividad.';

  @override
  String get agentsConfigMachine => 'Máquina';

  @override
  String get agentsConfigRuntime => 'Entorno';

  @override
  String get agentsConfigModel => 'Modelo';

  @override
  String get agentsConfigReasoning => 'Razonamiento';

  @override
  String get agentsEnvVarsTitle => 'Variables de entorno';

  @override
  String get agentsEnvVarsEmpty => 'Sin variables de entorno';

  @override
  String get agentsRetry => 'Reintentar';

  @override
  String get agentsActivityOnline => 'En línea';

  @override
  String get agentsActivityThinking => 'Pensando...';

  @override
  String get agentsActivityWorking => 'Trabajando...';

  @override
  String get agentsActivityError => 'Error';

  @override
  String agentsActivityErrorDetail(String detail) {
    return 'Error: $detail';
  }

  @override
  String get agentsActivityOffline => 'Sin conexión';

  @override
  String get agentsFormEditTitle => 'Editar agente';

  @override
  String get agentsFormCreateTitle => 'Crear agente';

  @override
  String get agentsFormNameRequired => 'El nombre es obligatorio.';

  @override
  String get agentsFormMachineRequired => 'La máquina es obligatoria.';

  @override
  String get agentsFormRuntimeRequired => 'El entorno es obligatorio.';

  @override
  String get agentsFormModelRequired => 'El modelo es obligatorio.';

  @override
  String get agentsFormNoMachines =>
      'No hay máquinas disponibles para este servidor.';

  @override
  String get agentsFormLabelMachine => 'Máquina';

  @override
  String get agentsFormLabelName => 'Nombre';

  @override
  String get agentsFormLabelDescription => 'Descripción';

  @override
  String get agentsFormLabelRuntime => 'Entorno';

  @override
  String get agentsFormLabelModel => 'Modelo';

  @override
  String get agentsFormLabelReasoningEffort => 'Nivel de razonamiento';

  @override
  String get agentsFormSave => 'Guardar';

  @override
  String get agentsFormCreate => 'Crear';

  @override
  String get agentsFormCancel => 'Cancelar';

  @override
  String get agentsFormRetry => 'Reintentar';

  @override
  String get agentsFormEnvVarsLabel => 'Variables de entorno';

  @override
  String get agentsFormEnvVarsAdd => 'Agregar variable';

  @override
  String get agentsFormEnvVarsKey => 'Clave';

  @override
  String get agentsFormEnvVarsValue => 'Valor';

  @override
  String get agentsReasoningLow => 'Bajo';

  @override
  String get agentsReasoningMedium => 'Medio';

  @override
  String get agentsReasoningHigh => 'Alto';

  @override
  String get agentsReasoningExtraHigh => 'Muy alto';

  @override
  String get agentsFormConfiguredDefault => 'Configurado por defecto';

  @override
  String get profileEditTitle => 'Editar perfil';

  @override
  String get profileEditSave => 'Guardar';

  @override
  String get profileEditSnackbarSaved => 'Perfil actualizado.';

  @override
  String get profileEditSnackbarAvatarSavedProfileFailed =>
      'Avatar actualizado. Error al guardar el perfil — toca Guardar para reintentar.';

  @override
  String get profileEditNewAvatarSelected => 'Nuevo avatar seleccionado';

  @override
  String get profileEditChangeAvatar => 'Cambiar avatar';

  @override
  String get profileEditSectionDetails => 'Detalles del perfil';

  @override
  String get profileEditDisplayNameLabel => 'Nombre para mostrar';

  @override
  String get profileEditDisplayNameRequired =>
      'El nombre para mostrar es obligatorio.';

  @override
  String get profileEditBioLabel => 'Bio / estado';

  @override
  String get profileTitleSelf => 'Mi perfil';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileRetry => 'Reintentar';

  @override
  String get profileNotAvailable => 'Perfil no disponible.';

  @override
  String get profileLabelUserId => 'ID de usuario';

  @override
  String get profileLabelUsername => 'Nombre de usuario';

  @override
  String get profileLabelEmail => 'Correo electrónico';

  @override
  String get profileLabelRole => 'Rol';

  @override
  String get profileLabelMemberSince => 'Miembro desde';

  @override
  String get profileEditComingSoon => 'Edición de perfil próximamente';

  @override
  String get profileEditButton => 'Editar perfil';

  @override
  String get profileThisIsYou => 'Eres tú';

  @override
  String get profileMessageButton => 'Mensaje';

  @override
  String profileDateFormat(String month, int day, int year) {
    return '$day de $month de $year';
  }

  @override
  String get profileMonthJan => 'ene';

  @override
  String get profileMonthFeb => 'feb';

  @override
  String get profileMonthMar => 'mar';

  @override
  String get profileMonthApr => 'abr';

  @override
  String get profileMonthMay => 'may';

  @override
  String get profileMonthJun => 'jun';

  @override
  String get profileMonthJul => 'jul';

  @override
  String get profileMonthAug => 'ago';

  @override
  String get profileMonthSep => 'sep';

  @override
  String get profileMonthOct => 'oct';

  @override
  String get profileMonthNov => 'nov';

  @override
  String get profileMonthDec => 'dic';

  @override
  String get settingsEditProfileTitle => 'Editar perfil';

  @override
  String get settingsEditProfileSubtitle => 'Actualiza tu nombre, bio y avatar';

  @override
  String get inboxTitle => 'Bandeja de entrada';

  @override
  String get inboxMarkAllReadTooltip => 'Marcar todo como leído';

  @override
  String get inboxLoadFailed => 'Error al cargar la bandeja de entrada';

  @override
  String get inboxRetry => 'Reintentar';

  @override
  String get inboxEmptyTitle => '¡Todo al día!';

  @override
  String get inboxEmptySubtitle => 'No hay mensajes en tu bandeja de entrada';

  @override
  String get inboxActionMarkRead => 'Marcar como leído';

  @override
  String get inboxSwipeLabelRead => 'Leído';

  @override
  String get inboxFilterUnread => 'No leídos';

  @override
  String get inboxFilterMentions => '@Menciones';

  @override
  String get inboxFilterDms => 'Mensajes directos';

  @override
  String get inboxFilterAll => 'Todos';

  @override
  String get inboxMentionBadge => '@tú';

  @override
  String get inboxTimeNow => 'ahora';

  @override
  String inboxTimeMinutes(int count) {
    return '${count}min';
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
  String get settingsAppearanceTitle => 'Apariencia';

  @override
  String get settingsAppearanceThemeSection => 'Tema';

  @override
  String get settingsThemeSystemTitle => 'Seguir sistema';

  @override
  String get settingsThemeSystemDescription =>
      'Usar el tema de tu dispositivo.';

  @override
  String get settingsThemeLightTitle => 'Claro';

  @override
  String get settingsThemeLightDescription => 'Siempre usar el tema claro.';

  @override
  String get settingsThemeDarkTitle => 'Oscuro';

  @override
  String get settingsThemeDarkDescription => 'Siempre usar el tema oscuro.';

  @override
  String get settingsHapticTitle => 'Retroalimentación háptica';

  @override
  String get settingsHapticOff => 'Desactivada';

  @override
  String get settingsHapticLight => 'Ligera';

  @override
  String get settingsHapticMedium => 'Media';

  @override
  String get settingsDiagnosticsPageTitle => 'Diagnósticos';

  @override
  String settingsDiagnosticsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'entradas',
      one: 'entrada',
    );
    return '$count $_temp0';
  }

  @override
  String get settingsDiagnosticsFilterAll => 'Todos';

  @override
  String get settingsDiagnosticsFilterInfo => 'Info';

  @override
  String get settingsDiagnosticsFilterWarning => 'Advertencia';

  @override
  String get settingsDiagnosticsFilterError => 'Error';

  @override
  String get settingsDiagnosticsEmpty => 'No hay entradas de diagnóstico';

  @override
  String get settingsDiagnosticsWorkerLoading =>
      'Proceso en segundo plano: cargando…';

  @override
  String get settingsDiagnosticsWorkerUnavailable =>
      'Diagnósticos del proceso en segundo plano no disponibles';

  @override
  String get settingsDiagnosticsWorkerNotRunning =>
      'Proceso en segundo plano: no activo';

  @override
  String get settingsDiagnosticsWorkerTitle => 'Proceso en segundo plano';

  @override
  String get settingsTranslationPageTitle => 'Traducción';

  @override
  String get settingsTranslationNoActiveWorkspace =>
      'No hay espacio de trabajo activo. La configuración de traducción es a nivel de espacio de trabajo.';

  @override
  String get settingsTranslationRetry => 'Reintentar';

  @override
  String get settingsTranslationSectionMode => 'Modo de traducción';

  @override
  String get settingsTranslationSectionLanguage => 'Idioma preferido';

  @override
  String get settingsTranslationModeAutoTitle => 'Automático';

  @override
  String get settingsTranslationModeManualTitle => 'Manual';

  @override
  String get settingsTranslationModeOffTitle => 'Desactivado';

  @override
  String get settingsTranslationModeAutoDescription =>
      'Traducir mensajes automáticamente al entrar en una conversación';

  @override
  String get settingsTranslationModeManualDescription =>
      'Traducir solo al tocar el botón de traducción';

  @override
  String get settingsTranslationModeOffDescription => 'Traducción desactivada';

  @override
  String get billingTitle => 'Facturación';

  @override
  String get billingUnavailableTitle => 'Facturación no disponible';

  @override
  String get billingUnavailableMessage =>
      'No pudimos cargar los detalles de facturación en este momento.';

  @override
  String get billingCouldNotOpenManagement =>
      'No se pudo abrir la gestión de facturación.';

  @override
  String get billingSubscriptionManagement => 'Gestión de suscripción';

  @override
  String get billingSubscriptionManagementDesc =>
      'Revisa tu suscripción actual y abre el portal de facturación cuando esté disponible.';

  @override
  String get billingSubscriptionSummary => 'Resumen de suscripción';

  @override
  String get billingStatusUnavailable => 'Estado no disponible';

  @override
  String get billingCurrentPrice => 'Precio actual';

  @override
  String get billingRenewalPeriod => 'Renovación / período';

  @override
  String get billingDetailsNotAvailable =>
      'Los detalles de facturación aún no están disponibles.';

  @override
  String get billingManagementUnavailable =>
      'Gestión de facturación no disponible';

  @override
  String get billingOpenPortal => 'Abrir portal de facturación';

  @override
  String get billingManagementUnavailableMessage =>
      'La gestión de facturación aún no está disponible para este espacio de trabajo. Los detalles de suscripción seguirán apareciendo aquí cuando el servidor los proporcione.';

  @override
  String get billingManageSubscription =>
      'Gestiona tu suscripción con el portal de facturación.';

  @override
  String get billingWorkspacePlanManagement =>
      'Gestión del plan del espacio de trabajo';

  @override
  String get billingWorkspacePlanDescActive =>
      'Revisa los límites actuales del espacio de trabajo y cualquier guía de actualización o degradación.';

  @override
  String get billingWorkspacePlanDescSelect =>
      'Selecciona un espacio de trabajo para revisar los límites de facturación y la guía del plan.';

  @override
  String get billingUsageSelectWorkspace =>
      'El plan del espacio de trabajo requiere seleccionar uno';

  @override
  String get billingUsageSelectWorkspaceMessage =>
      'Selecciona un espacio de trabajo para ver el uso actual, límites del plan y guía de actualización.';

  @override
  String get billingUsageUnavailableTitle =>
      'Uso del espacio de trabajo no disponible';

  @override
  String get billingUsageUnavailableMessage =>
      'Los detalles de uso no están disponibles en este momento.';

  @override
  String get billingServerUsageAndLimits => 'Uso y límites del servidor';

  @override
  String get billingPlanDetailsUnavailable =>
      'Detalles del plan no disponibles';

  @override
  String get billingMessageHistory => 'Historial de mensajes';

  @override
  String get billingPlanDowngraded => 'Plan del espacio de trabajo degradado';

  @override
  String billingPlanDowngradedMessage(String date) {
    return 'El plan de este espacio de trabajo fue degradado el $date. Actualiza para restaurar límites superiores.';
  }

  @override
  String get billingNeedMoreCapacity => '¿Necesitas más capacidad?';

  @override
  String get billingUpgradePortalMessage =>
      'Abre el portal de facturación para revisar las opciones de actualización para este plan.';

  @override
  String get billingUpgradeUnavailableMessage =>
      'Las opciones de actualización aparecerán aquí cuando la gestión de facturación esté disponible para este espacio de trabajo.';

  @override
  String get billingMessageHistoryUnlimited => 'Ilimitado';

  @override
  String get billingMessageHistoryOneDay => '1 día';

  @override
  String billingMessageHistoryDays(int count) {
    return '$count días';
  }

  @override
  String get threadsTitle => 'Hilos';

  @override
  String get threadsEmpty => 'Aún no sigues ningún hilo.';

  @override
  String get threadsSwipeDone => 'Hecho';

  @override
  String threadsRepliesCount(int count) {
    return '$count respuestas';
  }

  @override
  String threadsUnreadCount(int count) {
    return '$count sin leer';
  }

  @override
  String get threadsActionOpen => 'Abrir hilo';

  @override
  String get threadsActionDone => 'Hecho';

  @override
  String get threadRepliesTitle => 'Respuestas del hilo';

  @override
  String get threadRepliesMissingContext =>
      'Falta el contexto de ruta del hilo.';

  @override
  String get threadRepliesRetry => 'Reintentar';

  @override
  String get threadRepliesFollowTooltip => 'Seguir hilo';

  @override
  String get threadRepliesUnfollowTooltip => 'Dejar de seguir hilo';

  @override
  String get threadRepliesDoneTooltip => 'Marcar hilo como hecho';

  @override
  String get dmsSortAZ => 'Ordenar A-Z';

  @override
  String get dmsSortRecent => 'Ordenar por reciente';

  @override
  String get dmsMarkAllRead => 'Marcar todo como leído';

  @override
  String get dmsClearSearch => 'Borrar búsqueda';

  @override
  String get dmsMarkedUnread => 'Marcado como no leído';

  @override
  String get dmsNewMessageTitle => 'Nuevo mensaje';

  @override
  String get dmsTabPeople => 'Personas';

  @override
  String get dmsTabAgents => 'Agentes';

  @override
  String get dmsSearchHint => 'Buscar...';

  @override
  String get dmsNoAgentsFound => 'No se encontraron agentes.';

  @override
  String get dmsNoMembersFound => 'No se encontraron miembros.';

  @override
  String get dmsRetry => 'Reintentar';

  @override
  String get searchScopeAll => 'Todo';

  @override
  String get searchScopeMessages => 'Mensajes';

  @override
  String get searchScopeChannels => 'Canales';

  @override
  String get searchScopeContacts => 'Contactos';

  @override
  String get searchBadgeDm => 'MD';

  @override
  String get searchBadgeChannel => 'Canal';

  @override
  String get conversationFilesTitle => 'Archivos';

  @override
  String get conversationFilesRetry => 'Reintentar';

  @override
  String get conversationFilesEmpty => 'No hay archivos en este canal';

  @override
  String get conversationQuoteLoading => 'Cargando mensaje…';

  @override
  String get conversationQuoteNotFound => 'Mensaje no disponible';

  @override
  String conversationMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'miembros',
      one: 'miembro',
    );
    return '$count $_temp0';
  }

  @override
  String get conversationCloseSearch => 'Cerrar búsqueda';

  @override
  String get conversationSearchTooltip => 'Buscar';

  @override
  String get conversationInfoTooltip => 'Info de conversación';

  @override
  String get conversationScreenshotTooltip => 'Captura de pantalla';

  @override
  String get conversationMicDenied =>
      'Permiso de micrófono denegado. Por favor, habilítalo en Configuración.';

  @override
  String get conversationMicUnavailable =>
      'No se pudo iniciar la grabación. Verifica la disponibilidad del micrófono.';

  @override
  String conversationLoadFailed(String title) {
    return 'No se pudo cargar $title.';
  }

  @override
  String get conversationRetry => 'Reintentar';

  @override
  String conversationEmpty(String title) {
    return 'Aún no hay mensajes en $title.';
  }

  @override
  String get conversationPresenceOnline => 'En línea';

  @override
  String get conversationPresenceIdle => 'Inactivo';

  @override
  String get conversationPresenceOffline => 'Desconectado';

  @override
  String get conversationOfflineBanner =>
      'Estás sin conexión. Los mensajes se enviarán cuando te reconectes.';

  @override
  String get conversationOfflineAttachmentSnackbar =>
      'Estás sin conexión. Tu borrador y archivos adjuntos se conservan — toca Enviar de nuevo cuando estés en línea.';

  @override
  String outboxFailedBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes no se pudieron enviar',
      one: '1 mensaje no se pudo enviar',
    );
    return '$_temp0';
  }

  @override
  String get conversationInfoMute => 'Silenciar notificaciones';

  @override
  String get conversationInfoMuted => 'Las notificaciones están silenciadas';

  @override
  String get conversationInfoUnmuted => 'Recibiendo todas las notificaciones';

  @override
  String get conversationInfoMembers => 'Miembros';

  @override
  String get conversationInfoFiles => 'Archivos compartidos';

  @override
  String get conversationInfoPinned => 'Mensajes fijados';

  @override
  String get conversationInfoProfileSection => 'Perfil';

  @override
  String get conversationInfoDmSubtitle => 'Mensaje directo';

  @override
  String get conversationPinnedTitle => 'Mensajes fijados';

  @override
  String get conversationPinnedRetry => 'Reintentar';

  @override
  String get conversationPinnedEmpty => 'No hay mensajes fijados';

  @override
  String get conversationMessageAiBadge => 'IA';

  @override
  String conversationMessageReplyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'respuestas',
      one: 'respuesta',
    );
    return '$count $_temp0';
  }

  @override
  String get conversationMessageInThread => 'En hilo';

  @override
  String get conversationCopiedToClipboard => 'Copiado al portapapeles.';

  @override
  String get conversationLinkCopied => 'Enlace copiado';

  @override
  String get conversationMessageForwarded => 'Mensaje reenviado';

  @override
  String get conversationSendFailed => 'Error al enviar. Inténtalo de nuevo.';

  @override
  String get conversationTaskCreated => 'Tarea creada.';

  @override
  String get conversationQuoteFallback => '[Mensaje]';

  @override
  String get conversationProfileMessage => 'Mensaje';

  @override
  String get conversationSearchHint => 'Buscar en la conversación...';

  @override
  String get conversationSearchPrevious => 'Resultado anterior';

  @override
  String get conversationSearchNext => 'Siguiente resultado';

  @override
  String get conversationSearchClose => 'Cerrar búsqueda';

  @override
  String get conversationFormatBold => 'Negrita';

  @override
  String get conversationFormatItalic => 'Cursiva';

  @override
  String get conversationFormatInlineCode => 'Código en línea';

  @override
  String get conversationFormatCodeBlock => 'Bloque de código';

  @override
  String get conversationFormatLink => 'Enlace';

  @override
  String get conversationMessageListSemantics => 'Lista de mensajes';

  @override
  String get membersTitle => 'Miembros';

  @override
  String get membersRemoveTitle => '¿Eliminar miembro?';

  @override
  String get membersCancel => 'Cancelar';

  @override
  String get membersRemove => 'Eliminar';

  @override
  String get membersConfirm => 'Confirmar';

  @override
  String membersMemberRemoved(String name) {
    return '$name eliminado.';
  }

  @override
  String get membersInviteCopied => 'Enlace de invitación copiado.';

  @override
  String get membersSend => 'Enviar';

  @override
  String get membersGenerateLink => 'Generar enlace';

  @override
  String get membersChangeRole => 'Cambiar rol';

  @override
  String get membersRoleAdmin => 'Administrador';

  @override
  String get membersRoleMember => 'Miembro';

  @override
  String get membersMakeAdmin => 'Hacer administrador';

  @override
  String get membersMakeMember => 'Hacer miembro';

  @override
  String get membersRemoveMember => 'Eliminar miembro';

  @override
  String get membersProfileMessage => 'Mensaje';

  @override
  String get savedMessagesRetry => 'Reintentar';

  @override
  String get biometricTryAgain => 'Intentar de nuevo';

  @override
  String get biometricDisableContinue => 'Desactivar y continuar';

  @override
  String get biometricSkipForNow => 'Saltar por ahora';

  @override
  String get shareTargetTitle => 'Compartir en...';

  @override
  String get translationFailed => 'Traducción fallida. Toca para reintentar.';

  @override
  String membersRemoveBody(String name) {
    return '¿Eliminar a $name de este servidor?';
  }

  @override
  String get membersEmailValidationError =>
      'Introduce una dirección de correo válida';

  @override
  String get membersInviteTitle => 'Invitar persona';

  @override
  String get membersInviteEmailSection => 'Enviar invitación por correo';

  @override
  String get membersInviteEmailLabel => 'Correo';

  @override
  String get membersInviteEmailHint => 'user@example.com';

  @override
  String get membersInviteLinkSection => 'O compartir enlace de invitación';

  @override
  String get membersInviteCopyLink => 'Copiar enlace';

  @override
  String get membersRoleAdminSubtitle => 'Puede gestionar miembros e invitar';

  @override
  String get membersRoleMemberSubtitle =>
      'Acceso estándar al espacio de trabajo';

  @override
  String get savedMessagesTitle => 'Guardados';

  @override
  String get savedMessagesEmptyTitle => 'No hay mensajes guardados';

  @override
  String get savedMessagesEmptySubtitle =>
      'Mantén presionado un mensaje y toca \"Guardar\" para marcarlo.\nLos mensajes guardados aparecen aquí para referencia rápida.';

  @override
  String get savedMessagesUnsaveTooltip => 'Quitar guardado';

  @override
  String get savedMessagesSourceDm => '· MD';

  @override
  String savedMessagesSourceChannel(String name) {
    return '· # $name';
  }

  @override
  String get biometricPrompt => 'Autenticarse para continuar usando Slock';

  @override
  String get biometricLockTitle => 'Autenticarse para continuar';

  @override
  String get biometricLockSubtitle =>
      'Verifica tu identidad para acceder a Slock';

  @override
  String get biometricErrorLockout =>
      'Demasiados intentos. Inténtalo más tarde.';

  @override
  String get biometricErrorPermanentLockout =>
      'Biometría bloqueada. Usa el código de tu dispositivo.';

  @override
  String get biometricErrorNotAvailable =>
      'Biometría no disponible. Inténtalo de nuevo.';

  @override
  String get biometricErrorNotEnrolled =>
      'Sin biometría registrada. Inténtalo de nuevo.';

  @override
  String biometricErrorGeneric(int count) {
    return 'Autenticación fallida. Intentar de nuevo ($count/3).';
  }

  @override
  String get shareSearchHint => 'Buscar conversaciones...';

  @override
  String get shareSectionChannels => 'Canales';

  @override
  String get shareSectionDirectMessages => 'Mensajes directos';

  @override
  String get translationShowOriginal => 'Mostrar original';

  @override
  String get translationShowTranslation => 'Mostrar traducción';

  @override
  String get translationPending => 'Traduciendo…';

  @override
  String get notificationPrefAllTitle => 'Todos los mensajes';

  @override
  String get notificationPrefAllDescription =>
      'Recibir notificaciones de todos los mensajes.';

  @override
  String get notificationPrefMentionsTitle => 'Solo menciones y DMs';

  @override
  String get notificationPrefMentionsDescription =>
      'Solo recibir notificaciones de mensajes directos.';

  @override
  String get notificationPrefMuteTitle => 'Silenciar';

  @override
  String get notificationPrefMuteDescription =>
      'No mostrar notificaciones en primer plano.';

  @override
  String get membersInviteHumanTooltip => 'Invitar persona';

  @override
  String get membersErrorTitle => 'Miembros no disponibles';

  @override
  String get membersErrorMessage =>
      'No pudimos cargar los miembros del espacio de trabajo.';

  @override
  String get membersEmptyMessage => 'Aún no hay miembros.';

  @override
  String membersInviteSent(String email) {
    return 'Correo de invitación enviado a $email.';
  }

  @override
  String get membersSearchHint => 'Buscar miembros…';

  @override
  String get membersSearchEmpty => 'Ningún miembro coincide con tu búsqueda.';

  @override
  String get membersSectionHumans => 'Personas';

  @override
  String get membersSectionAgents => 'Agentes';

  @override
  String membersRoleChanged(String name, String role) {
    return '$name ahora es $role.';
  }

  @override
  String get membersRoleOwner => 'Propietario';

  @override
  String get homeSearchTooltip => 'Buscar';

  @override
  String get audioPlaybackFailed => 'Error en la reproducción de audio';

  @override
  String get crashRecoveryTitle => 'Aplicación recuperada';

  @override
  String get crashRecoveryMessage =>
      'La aplicación se detuvo inesperadamente durante tu última sesión. Puedes exportar registros de diagnóstico para ayudarnos a investigar.';

  @override
  String get crashRecoveryContinue => 'Continuar';

  @override
  String get crashRecoveryExport => 'Exportar diagnósticos';

  @override
  String get filePreviewShareFailed => 'Error al compartir el archivo.';

  @override
  String get filePreviewShareTooltip => 'Compartir';

  @override
  String get filePreviewOpenExternal => 'Abrir en aplicación externa';

  @override
  String get filePreviewRetry => 'Reintentar';

  @override
  String get filePreviewOpenWith => 'Abrir con…';

  @override
  String get annotationDraw => 'Dibujar';

  @override
  String get annotationText => 'Texto';

  @override
  String get annotationArrow => 'Flecha';

  @override
  String get annotationUndo => 'Deshacer';

  @override
  String get annotationRedo => 'Rehacer';

  @override
  String get annotationColorRed => 'Rojo';

  @override
  String get annotationColorGreen => 'Verde';

  @override
  String get annotationColorBlue => 'Azul';

  @override
  String get annotationColorYellow => 'Amarillo';

  @override
  String get annotationColorWhite => 'Blanco';

  @override
  String get annotationColorBlack => 'Negro';

  @override
  String get voiceRecorderCancel => 'Cancelar grabación';

  @override
  String get voiceRecorderSend => 'Enviar mensaje de voz';

  @override
  String get voiceMessageScrubber => 'Control de mensaje de voz';

  @override
  String get voiceBubblePause => 'Pausar';

  @override
  String get voiceBubblePlay => 'Reproducir';

  @override
  String get memberListItemMessageTooltip => 'Mensaje';

  @override
  String get memberListItemAdminActionsTooltip => 'Acciones de administración';

  @override
  String get homeOverviewSemantics => 'Vista general';

  @override
  String linkPreviewSemantics(String domain) {
    return 'Vista previa del enlace: $domain';
  }

  @override
  String get textPreviewShowMore => 'Mostrar más';

  @override
  String get profileAvatarEditSemantics => 'Editar avatar de perfil';

  @override
  String get screenshotCanvasSemantics => 'Lienzo de anotación de captura';

  @override
  String get voiceWaveformSemantics => 'Forma de onda de grabación';

  @override
  String get unreadFilterLabel => 'No leídos';

  @override
  String get allFilterLabel => 'Todos';

  @override
  String get agentEditTooltip => 'Editar agente';

  @override
  String get agentDeleteTooltip => 'Eliminar agente';

  @override
  String get searchClearTooltip => 'Borrar búsqueda';

  @override
  String get channelMembersAddTooltip => 'Añadir miembro';

  @override
  String get channelMembersRemoveTooltip => 'Eliminar miembro';

  @override
  String get channelFilesTooltip => 'Archivos del canal';

  @override
  String get channelMembersTooltip => 'Miembros del canal';

  @override
  String get addHumanToChannelTooltip => 'Añadir al canal';

  @override
  String get addAgentToChannelTooltip => 'Añadir agente al canal';

  @override
  String get togglePasswordVisibilityTooltip =>
      'Alternar visibilidad de contraseña';

  @override
  String get dismissAnnouncementTooltip => 'Cerrar';

  @override
  String get shareTargetCancelTooltip => 'Cancelar';

  @override
  String get dmAgentBadge => 'AGENTE';

  @override
  String get dmActionMoveUp => 'Subir';

  @override
  String get dmActionMoveDown => 'Bajar';

  @override
  String get dmActionPin => 'Fijar conversación';

  @override
  String get dmActionUnpin => 'Desfijar conversación';

  @override
  String get dmActionMarkUnread => 'Marcar como no leído';

  @override
  String get dmActionClose => 'Cerrar conversación';

  @override
  String get taskOverlayDropTitle => 'Soltar para cambiar estado';

  @override
  String get taskOverlayCancelHint => 'Soltar fuera de las cajas para cancelar';

  @override
  String taskOverlayMovedTo(String status) {
    return 'Movido a $status';
  }

  @override
  String get taskOverlayCurrentBadge => 'Actual';

  @override
  String get taskOverlayReleaseHint => 'Soltar para mover aquí';

  @override
  String get taskStatusTodo => 'Pendiente';

  @override
  String get taskStatusInProgress => 'En progreso';

  @override
  String get taskStatusInReview => 'En revisión';

  @override
  String get taskStatusDone => 'Hecho';

  @override
  String get taskStatusDescTodo => 'No iniciado';

  @override
  String get taskStatusDescInProgress => 'En proceso';

  @override
  String get taskStatusDescInReview => 'Necesita revisión';

  @override
  String get taskStatusDescDone => 'Completado';

  @override
  String get homeRetrySemantics => 'Reintentar';

  @override
  String get homeUnreadOverflowSemantics =>
      'Ver todas las conversaciones no leídas';

  @override
  String get homeServerSwitcherSemantics => 'Cambiar espacio de trabajo';

  @override
  String get unreadFilterToggleSemantics => 'Alternar filtro de no leídos';

  @override
  String unreadListItemSemantics(String title) {
    return 'Abrir conversación: $title';
  }

  @override
  String get inboxItemSemantics => 'Abrir notificación';

  @override
  String inboxFilterTabSemantics(String label) {
    return 'Filtro: $label';
  }

  @override
  String searchScopeTabSemantics(String label) {
    return 'Ámbito de búsqueda: $label';
  }

  @override
  String get filePreviewDismissSemantics => 'Deslizar hacia abajo para cerrar';

  @override
  String messageLinkChipSemantics(String url) {
    return 'Abrir enlace: $url';
  }

  @override
  String get attachmentImageFallbackSemantics => 'Imagen adjunta';

  @override
  String get navInbox => 'Bandeja';

  @override
  String get homeAppBarFallbackTitle => 'Slock';

  @override
  String get homeTypePillThread => 'HILO';

  @override
  String get homeTypePillChannel => 'CANAL';

  @override
  String get homeTypePillDm => 'MD';

  @override
  String get unreadOtherSources => 'Otras fuentes no leídas';

  @override
  String routerPageNotFound(String uri) {
    return 'Página no encontrada: $uri';
  }

  @override
  String get shareSendFailed => 'Error al enviar. Inténtalo de nuevo.';

  @override
  String get filePreviewFallbackTitle => 'Vista previa';

  @override
  String get filePreviewFallbackBody => 'Vista previa no disponible';

  @override
  String get filePreviewFallbackBack => 'Volver';

  @override
  String get deepLinkAccessDeniedTitle => 'No tienes acceso';

  @override
  String get deepLinkAccessDeniedMessage =>
      'No tienes acceso a este recurso. Puede ser privado, haberse eliminado o estar fuera de tu espacio actual.';

  @override
  String get deepLinkNotFoundTitle => 'Recurso no encontrado';

  @override
  String get deepLinkNotFoundMessage =>
      'No se pudo encontrar este recurso. Puede haberse eliminado o el enlace puede estar desactualizado.';

  @override
  String get deepLinkBackButton => 'Volver a Slock';

  @override
  String get errorRetry => 'Reintentar';

  @override
  String get errorShareDiagnostics => 'Compartir diagnósticos';

  @override
  String get fatalTitle => 'No se puede iniciar';

  @override
  String get fatalBodyMissingConfig =>
      'La aplicación carece de la configuración necesaria y no puede iniciarse. Esto suele significar que se compiló sin las variables de entorno requeridas.';

  @override
  String get fatalBodyGeneric =>
      'Algo salió mal durante el inicio. Por favor, reinicia la aplicación.';

  @override
  String get fatalHintDeveloper =>
      'Si eres desarrollador, asegúrate de que todos los valores --dart-define requeridos se proporcionan al compilar.';

  @override
  String get fatalHintGeneric =>
      'Si el problema persiste, reinstala la aplicación o contacta con soporte.';

  @override
  String get fatalCopyDiagnostics => 'Copiar diagnósticos';

  @override
  String get fatalDiagnosticsCopied => 'Diagnósticos copiados al portapapeles';

  @override
  String get diagExportTitle => 'Exportar diagnósticos';

  @override
  String get diagExportSubtitle =>
      'Comparte los registros de diagnóstico con el equipo de desarrollo.';

  @override
  String get diagCopyToClipboard => 'Copiar al portapapeles';

  @override
  String get diagShare => 'Compartir';

  @override
  String get diagSaveToFile => 'Guardar en archivo';

  @override
  String get diagCopied => 'Copiado al portapapeles';

  @override
  String get diagCopyFailed => 'Error al copiar';

  @override
  String get diagShared => 'Compartido correctamente';

  @override
  String get diagShareFailed => 'Error al compartir';

  @override
  String diagSaved(String path) {
    return 'Guardado en $path';
  }

  @override
  String get diagSaveFailed => 'Error al guardar';

  @override
  String get filePreviewNoUrl => 'No hay URL de descarga disponible.';

  @override
  String get filePreviewLoadFailed => 'Error al cargar el archivo adjunto.';

  @override
  String get filePreviewPdfDownloadFailed => 'Error al descargar el PDF.';

  @override
  String get filePreviewDownloadingPdf => 'Descargando PDF…';

  @override
  String get filePreviewLoading => 'Cargando…';

  @override
  String get filePreviewPdfUnavailable => 'Archivo PDF no disponible.';

  @override
  String get filePreviewPdfRenderFailed => 'Error al renderizar el PDF.';

  @override
  String get filePreviewImageLoadFailed => 'No se puede cargar la imagen.';

  @override
  String get avatarUploadInvalidResponse => 'Respuesta inválida del servidor.';

  @override
  String get avatarUploadFailed => 'Error de subida.';

  @override
  String get avatarUploadFailedRetry => 'Error de subida. Inténtalo de nuevo.';

  @override
  String get timeJustNow => 'ahora mismo';

  @override
  String timeMinutesAgo(int count) {
    return 'hace ${count}m';
  }

  @override
  String timeHoursAgo(int count) {
    return 'hace ${count}h';
  }

  @override
  String get billingResourceAgents => 'Agentes';

  @override
  String get billingResourceMachines => 'Máquinas';

  @override
  String get billingResourceChannels => 'Canales';

  @override
  String get notificationNewMessageFallback => 'Mensaje nuevo';

  @override
  String get notificationActionReply => 'Responder';

  @override
  String get notificationActionMarkRead => 'Marcar como leído';

  @override
  String get notificationActionReplyHint => 'Escribe una respuesta';

  @override
  String typingIndicatorOne(String name) {
    return '$name está escribiendo...';
  }

  @override
  String typingIndicatorTwo(String first, String second) {
    return '$first y $second están escribiendo...';
  }

  @override
  String get typingIndicatorSeveral => 'Varias personas están escribiendo...';

  @override
  String typingIndicatorThreeOrMore(String allButLast, String last) {
    return '$allButLast y $last están escribiendo...';
  }

  @override
  String get connectionReconnecting => 'Reconectando...';

  @override
  String get conversationDefaultTitleDm => 'Mensaje directo';

  @override
  String get userFallbackDisplayName => 'Usuario';

  @override
  String get agentsActivityLogOnline => 'En línea';

  @override
  String get agentsActivityLogThinking => 'Pensando';

  @override
  String get agentsActivityLogWorking => 'Trabajando';

  @override
  String get agentsActivityLogError => 'Error';

  @override
  String agentsActivityLogErrorDetail(String detail) {
    return 'Error: $detail';
  }

  @override
  String get agentsActivityLogOffline => 'Sin conexión';

  @override
  String get senderLabelAgent => 'Agente';

  @override
  String get senderLabelMember => 'Miembro';

  @override
  String get senderLabelSystem => 'Sistema';

  @override
  String sharePreviewAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos adjuntos',
      one: '1 archivo adjunto',
    );
    return '$_temp0';
  }

  @override
  String get inboxFallbackDmName => 'Desconocido';

  @override
  String get inboxFallbackMemberName => 'Miembro';

  @override
  String get diagnosticsExportFabTooltip => 'Exportar diagnósticos';

  @override
  String get scrollToBottomFabTooltip => 'Ir al final';

  @override
  String get replyPreviewDismissSemantics => 'Cerrar respuesta';

  @override
  String get linkedTaskBadgeSemantics => 'Ver tarea vinculada';

  @override
  String get messageSelectionToggleSemantics => 'Alternar selección de mensaje';

  @override
  String get messageContextMenuSemantics => 'Opciones de mensaje';

  @override
  String get quotedMessageTapSemantics => 'Ir al mensaje citado';

  @override
  String get diagnosticsEntryExpandSemantics =>
      'Expandir entrada de diagnóstico';

  @override
  String get quoteJumpDismissSemantics => 'Cerrar';

  @override
  String get unnamedMachineFallback => 'Máquina sin nombre';

  @override
  String get unnamedWorkspaceFallback => 'Espacio sin nombre';

  @override
  String agentsStatusGroupSemantics(String status, int count) {
    return '$status, $count agentes';
  }

  @override
  String agentsRowSemantics(String name, String activity) {
    return '$name, $activity';
  }

  @override
  String get agentsRowActionsHint => 'Mostrar acciones';

  @override
  String get mentionSuggestionsSemantics => 'Sugerencias de mención';

  @override
  String mentionSuggestionItemSemantics(String name) {
    return 'Mencionar a $name';
  }

  @override
  String get oauthDividerLabel => 'o continuar con';

  @override
  String oauthProviderButton(String provider) {
    return 'Continuar con $provider';
  }

  @override
  String get oauthCancelledMessage => 'Inicio de sesión cancelado.';

  @override
  String get oauthProviderDeniedMessage =>
      'El proveedor denegó el acceso. Intenta de nuevo o usa otro método de inicio de sesión.';

  @override
  String get oauthConflictMessage =>
      'Este correo ya está registrado. Inicia sesión con tu contraseña.';

  @override
  String get oauthNetworkErrorMessage =>
      'No se pudo conectar con el proveedor. Verifica tu conexión e intenta de nuevo.';

  @override
  String get channelActionArchive => 'Archivar canal';

  @override
  String get channelActionUnarchive => 'Desarchivar canal';

  @override
  String get channelArchivedBanner => 'Este canal está archivado.';

  @override
  String get channelArchiveConfirmTitle => '¿Archivar canal?';

  @override
  String get channelArchiveConfirmBody =>
      'Los canales archivados son de solo lectura. Los miembros pueden ver los mensajes pero no enviar nuevos.';

  @override
  String get channelUnarchiveConfirmTitle => '¿Desarchivar canal?';

  @override
  String get channelUnarchiveConfirmBody =>
      'Esto restaurará el canal a estado activo y permitirá a los miembros enviar mensajes nuevamente.';

  @override
  String serverSwitcherUnreadBadge(String name) {
    return '$name, tiene mensajes no leídos';
  }

  @override
  String get outboxQueueFull =>
      'La cola de mensajes está llena. Espere a que se envíen los mensajes pendientes.';

  @override
  String get taskRefNotFound => 'Tarea no encontrada';

  @override
  String get taskRefLoadFailed => 'Error al cargar la tarea';

  @override
  String get notificationNoAccess => 'No tienes acceso a este canal';

  @override
  String get taskClaimConflict =>
      'Esta tarea ya fue reclamada por otra persona';

  @override
  String get composerMessageTooLong => 'Mensaje demasiado largo';

  @override
  String composerCharacterCount(int current, int max) {
    return '$current/$max';
  }

  @override
  String get settingsAppearanceSwipeSection =>
      'Deslizamientos de conversaciones';

  @override
  String get settingsSwipeLeftTitle => 'Deslizar a la izquierda';

  @override
  String get settingsSwipeRightTitle => 'Deslizar a la derecha';

  @override
  String get settingsSwipeLeftDescription =>
      'Elige qué ocurre al deslizar una conversación a la izquierda.';

  @override
  String get settingsSwipeRightDescription =>
      'Elige qué ocurre al deslizar una conversación a la derecha.';

  @override
  String get conversationSwipeActionNone => 'Ninguna';

  @override
  String get conversationSwipeActionArchive => 'Archivar';

  @override
  String get conversationSwipeActionPin => 'Fijar / desfijar';

  @override
  String get conversationSwipeActionMute => 'Silenciar / reactivar';

  @override
  String get conversationSwipeArchive => 'Archivar';

  @override
  String get conversationSwipePin => 'Fijar';

  @override
  String get conversationSwipeUnpin => 'Desfijar';

  @override
  String get conversationSwipeMute => 'Silenciar';

  @override
  String get conversationSwipeUnmute => 'Reactivar';

  @override
  String conversationSwipeArchived(String name) {
    return 'Archivado $name';
  }

  @override
  String get undoAction => 'Deshacer';

  @override
  String get shareUploadProgressSingle => 'Subiendo...';

  @override
  String shareUploadProgressMulti(int current, int total) {
    return 'Subiendo archivo $current de $total...';
  }

  @override
  String summaryCardAwayDuration(int minutes) {
    return 'Ausente $minutes min';
  }

  @override
  String get summaryCardUnread => 'sin leer';

  @override
  String get summaryCardMentions => '@tú';

  @override
  String get summaryCardNewTasks => 'tareas nuevas';

  @override
  String get summaryCardMarkAllRead => 'Marcar todo como leído';

  @override
  String get summaryCardMarkReadFailed => 'Error al marcar, reintentar';

  @override
  String get summaryCardExpand => 'Detalles ▼';

  @override
  String get summaryCardCollapse => 'Contraer ▲';

  @override
  String get summaryCardMentionedSuffix => '@tú';

  @override
  String summaryCardMoreChannels(int count) {
    return '+$count más';
  }

  @override
  String get summaryCardTaskAssigned => 'asignada a ti';

  @override
  String get summaryCardDismiss => 'Cerrar resumen';
}
