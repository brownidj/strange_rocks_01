class FieldPackManifestValidationError implements Exception {
  const FieldPackManifestValidationError(this.message);

  final String message;

  @override
  String toString() => 'FieldPackManifestValidationError: $message';
}
