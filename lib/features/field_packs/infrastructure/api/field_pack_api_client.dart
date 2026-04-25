abstract interface class FieldPackApiClient {
  Future<Map<String, Object?>> fetchManifest(String packId);
  Future<void> downloadPackArchive(String packId, String destinationPath);
}
