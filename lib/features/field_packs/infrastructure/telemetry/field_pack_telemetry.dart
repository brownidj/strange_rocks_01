import 'package:flutter/foundation.dart';

abstract interface class FieldPackTelemetry {
  void recordStart(String packId);
  void recordStage(
    String packId,
    String stage, {
    Map<String, Object?>? metadata,
  });
  void recordSuccess(String packId, Duration duration);
  void recordFailure(
    String packId,
    String stage,
    Object error,
    Duration duration,
  );
}

class FieldPackDebugTelemetry implements FieldPackTelemetry {
  const FieldPackDebugTelemetry({this.enabled = kDebugMode});

  final bool enabled;

  @override
  void recordStart(String packId) {
    _log('[field-pack][$packId] started');
  }

  @override
  void recordStage(
    String packId,
    String stage, {
    Map<String, Object?>? metadata,
  }) {
    if (metadata == null || metadata.isEmpty) {
      _log('[field-pack][$packId] stage=$stage');
      return;
    }
    _log('[field-pack][$packId] stage=$stage data=$metadata');
  }

  @override
  void recordSuccess(String packId, Duration duration) {
    _log(
      '[field-pack][$packId] success duration_ms=${duration.inMilliseconds}',
    );
  }

  @override
  void recordFailure(
    String packId,
    String stage,
    Object error,
    Duration duration,
  ) {
    _log(
      '[field-pack][$packId] failure stage=$stage duration_ms=${duration.inMilliseconds} error=$error',
    );
  }

  void _log(String message) {
    if (!enabled) {
      return;
    }
    debugPrint(message);
  }
}
