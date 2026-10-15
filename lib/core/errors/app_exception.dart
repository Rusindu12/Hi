/// Typed errors so the UI can decide what to show without string matching.
///
/// Repositories throw these; presentation code converts them into a localised
/// message with `localizeError` (see core/errors/error_messages.dart).
sealed class AppException implements Exception {
  const AppException(this.debugMessage, {this.cause, this.stackTrace});

  /// Developer-facing detail. Never shown to users.
  final String debugMessage;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $debugMessage';
}

/// No connectivity, timeout, or a DNS/HTTP failure.
final class NetworkException extends AppException {
  const NetworkException(super.debugMessage, {super.cause, super.stackTrace});
}

/// Requested catalogue item, question set, or file does not exist.
final class NotFoundException extends AppException {
  const NotFoundException(super.debugMessage, {super.cause, super.stackTrace});
}

/// Disk full, write denied, or a corrupt cache entry.
final class StorageException extends AppException {
  const StorageException(super.debugMessage, {super.cause, super.stackTrace});
}

/// A download record exists but the file is gone (user cleared data, etc.).
final class FileMissingException extends AppException {
  const FileMissingException(super.debugMessage, {super.cause, super.stackTrace});
}

/// Bundled seed assets are malformed, or the remote catalogue does not parse.
final class CatalogueException extends AppException {
  const CatalogueException(super.debugMessage, {super.cause, super.stackTrace});
}

/// Firebase classes were touched while [AppConfig.useFirebase] is false.
/// This is a programming error, not a user-facing condition.
final class FirebaseDisabledException extends AppException {
  const FirebaseDisabledException(super.debugMessage)
      : super();
}

/// The item's rights do not allow SriEdu to mirror or cache it; it must be
/// opened at its official source instead. See docs/CONTENT_POLICY.md.
final class ContentPolicyException extends AppException {
  const ContentPolicyException(super.debugMessage, {super.cause, super.stackTrace});
}

/// Wraps the `dio`/platform error surface into something catchable by callers.
AppException mapToAppException(Object error, [StackTrace? stackTrace]) {
  if (error is AppException) {
    return error;
  }
  return NetworkException(
    error.toString(),
    cause: error,
    stackTrace: stackTrace,
  );
}
