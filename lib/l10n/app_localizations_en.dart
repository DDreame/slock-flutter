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
  String get splashSubtitle => 'Preparing your workspace console...';

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
}
