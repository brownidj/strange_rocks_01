sealed class FieldPackPipelineError implements Exception {
  const FieldPackPipelineError(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class FieldPackNetworkError extends FieldPackPipelineError {
  const FieldPackNetworkError(super.message, {super.cause});
}

class FieldPackStorageError extends FieldPackPipelineError {
  const FieldPackStorageError(super.message, {super.cause});
}

class FieldPackChecksumError extends FieldPackPipelineError {
  const FieldPackChecksumError(super.message, {super.cause});
}

class FieldPackSchemaMismatchError extends FieldPackPipelineError {
  const FieldPackSchemaMismatchError(super.message, {super.cause});
}

class FieldPackUnpackError extends FieldPackPipelineError {
  const FieldPackUnpackError(super.message, {super.cause});
}

class FieldPackUnexpectedError extends FieldPackPipelineError {
  const FieldPackUnexpectedError(super.message, {super.cause});
}

class FieldPackCompatibilityError extends FieldPackPipelineError {
  const FieldPackCompatibilityError(super.message, {super.cause});
}

class FieldPackInsufficientStorageError extends FieldPackPipelineError {
  const FieldPackInsufficientStorageError(super.message, {super.cause});
}
