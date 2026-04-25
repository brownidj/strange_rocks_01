class FieldPackAsset {
  const FieldPackAsset({
    required this.path,
    required this.kind,
    required this.sizeBytes,
    required this.sha256,
  });

  final String path;
  final String kind;
  final int sizeBytes;
  final String sha256;
}
