import 'dart:typed_data';

class BuildJob {
  BuildJob({
    required this.jobId,
    required this.status,
    required this.stage,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String jobId;
  String status;
  String stage;
  DateTime createdAtUtc;
  DateTime updatedAtUtc;
  String? packId;
  String? errorCode;
  String? errorMessage;
}

class PublishedPack {
  PublishedPack({required this.packId, required this.manifest, required this.zipBytes});

  final String packId;
  final Map<String, Object?> manifest;
  final Uint8List zipBytes;
}
