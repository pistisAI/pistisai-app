/// Typed settings errors.
library;

/// Settings error types
enum SettingsErrorType {
  /// Validation error
  validation,

  /// Save operation failed
  saveFailed,

  /// Load operation failed
  loadFailed,

  /// Connection error (e.g., provider connection test failed)
  connectionFailed,

  /// Import/export error
  importExportFailed,

  /// Storage unavailable
  storageUnavailable,

  /// Unknown error
  unknown,
}

/// Settings error with type and message
class SettingsError {
  /// Error type
  final SettingsErrorType type;

  /// Error message
  final String message;

  /// Field-specific errors (for validation errors)
  final Map<String, String>? fieldErrors;

  /// Whether this error is retryable
  final bool isRetryable;

  /// Original exception (if any)
  final Exception? originalException;

  const SettingsError({
    required this.type,
    required this.message,
    this.fieldErrors,
    this.isRetryable = false,
    this.originalException,
  });

  /// Create a validation error
  factory SettingsError.validation(
    String message, {
    Map<String, String>? fieldErrors,
  }) {
    return SettingsError(
      type: SettingsErrorType.validation,
      message: message,
      fieldErrors: fieldErrors,
      isRetryable: false,
    );
  }

  /// Create a save error
  factory SettingsError.saveFailed(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.saveFailed,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  /// Create a load error
  factory SettingsError.loadFailed(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.loadFailed,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  /// Create a connection error
  factory SettingsError.connectionFailed(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.connectionFailed,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  /// Create an import/export error
  factory SettingsError.importExportFailed(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.importExportFailed,
      message: message,
      isRetryable: false,
      originalException: originalException,
    );
  }

  /// Create a storage unavailable error
  factory SettingsError.storageUnavailable(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.storageUnavailable,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  /// Create an unknown error
  factory SettingsError.unknown(
    String message, {
    Exception? originalException,
  }) {
    return SettingsError(
      type: SettingsErrorType.unknown,
      message: message,
      isRetryable: true,
      originalException: originalException,
    );
  }

  @override
  String toString() => 'SettingsError($type): $message';
}
