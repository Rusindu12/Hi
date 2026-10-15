import '../../l10n/generated/app_localizations.dart';
import 'app_exception.dart';

/// Turns a thrown [AppException] into a localised, user-safe sentence.
///
/// Never surface `debugMessage` to users: it can contain urls, Firestore paths
/// or platform error codes.
String localizeError(AppLocalizations l10n, Object error) {
  return switch (error) {
    NetworkException() => l10n.errNetwork,
    NotFoundException() => l10n.errNotFound,
    StorageException() => l10n.errStorage,
    FileMissingException() => l10n.errFileMissing,
    CatalogueException() => l10n.errCatalogue,
    FirebaseDisabledException() => l10n.errFirebaseDisabled,
    ContentPolicyException() => l10n.errOfficialOnly,
    _ => l10n.errGeneric,
  };
}
