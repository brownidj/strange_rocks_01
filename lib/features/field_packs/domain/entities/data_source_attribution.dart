class DataSourceAttribution {
  const DataSourceAttribution({
    required this.provider,
    required this.acquiredAtUtc,
    required this.license,
    required this.attribution,
  });

  final String provider;
  final String acquiredAtUtc;
  final String license;
  final String attribution;
}
