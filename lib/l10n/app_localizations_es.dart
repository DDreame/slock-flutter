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
}
