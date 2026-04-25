class FieldArea {
  const FieldArea({
    required this.id,
    required this.name,
    required this.geoJson,
    required this.bbox,
  });

  final String id;
  final String name;
  final Map<String, Object?> geoJson;
  final Map<String, num> bbox;
}
