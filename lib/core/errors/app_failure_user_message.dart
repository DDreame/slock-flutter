import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Maps [AppFailure] subtypes to user-friendly, localized messages.
///
/// Replaces the raw `failure.message ?? 'hardcoded fallback'` pattern across
/// 50+ presentation-layer callsites (#790). The raw `message` field contains
/// server/Dio internals ("Connection reset by peer", format exceptions) which
/// must never be shown to users.
extension AppFailureUserMessage on AppFailure {
  /// Returns a localized, user-facing error string for this failure.
  ///
  /// Uses exhaustive switch on the sealed [AppFailure] hierarchy so the
  /// compiler enforces coverage when new subtypes are added.
  String userMessage(AppLocalizations l10n) => switch (this) {
        NetworkFailure() => l10n.errorNetwork,
        TimeoutFailure() => l10n.errorTimeout,
        UnauthorizedFailure() => l10n.errorUnauthorized,
        ForbiddenFailure() => l10n.errorForbidden,
        NotFoundFailure() => l10n.errorNotFound,
        ConflictFailure() => l10n.errorConflict,
        ValidationFailure() => l10n.errorValidation,
        RateLimitFailure() => l10n.errorRateLimit,
        ServerFailure() => l10n.errorServer,
        CancelledFailure() => l10n.errorCancelled,
        SerializationFailure() => l10n.errorUnknown,
        UnknownFailure() => l10n.errorUnknown,
      };
}
