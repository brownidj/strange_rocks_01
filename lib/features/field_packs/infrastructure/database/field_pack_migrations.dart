const int kFieldPackDbVersion = 2;

const List<String> kFieldPackMigrationV1 = <String>[
  '''
CREATE TABLE IF NOT EXISTS field_packs (
  id TEXT PRIMARY KEY,
  version TEXT NOT NULL,
  name TEXT,
  status TEXT NOT NULL,
  local_root_path TEXT NOT NULL,
  manifest_json TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  downloaded_at_utc TEXT,
  is_active INTEGER NOT NULL DEFAULT 0
)
''',
  '''
CREATE TABLE IF NOT EXISTS field_pack_assets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pack_id TEXT NOT NULL,
  path TEXT NOT NULL,
  kind TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  is_present INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(pack_id) REFERENCES field_packs(id) ON DELETE CASCADE
)
''',
  '''
CREATE TABLE IF NOT EXISTS field_areas (
  id TEXT PRIMARY KEY,
  pack_id TEXT,
  name TEXT,
  geojson TEXT NOT NULL,
  bbox_json TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  FOREIGN KEY(pack_id) REFERENCES field_packs(id) ON DELETE SET NULL
)
''',
  'CREATE INDEX IF NOT EXISTS idx_field_packs_active ON field_packs(is_active)',
  'CREATE INDEX IF NOT EXISTS idx_field_pack_assets_pack_id ON field_pack_assets(pack_id)',
  'CREATE INDEX IF NOT EXISTS idx_field_areas_pack_id ON field_areas(pack_id)',
];

const List<String> kFieldPackMigrationV2 = <String>[
  '''
CREATE TABLE IF NOT EXISTS adhoc_collection_events (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS adhoc_photo_series (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  title TEXT NOT NULL,
  started_at_utc TEXT NOT NULL,
  ended_at_utc TEXT,
  anchor_latitude REAL,
  anchor_longitude REAL,
  max_radius_meters REAL NOT NULL DEFAULT 0,
  location_incomplete INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(event_id) REFERENCES adhoc_collection_events(id) ON DELETE CASCADE
)
''',
  '''
CREATE TABLE IF NOT EXISTS adhoc_series_photos (
  id TEXT PRIMARY KEY,
  series_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  captured_at_utc TEXT,
  metadata_latitude REAL,
  metadata_longitude REAL,
  fallback_latitude REAL,
  fallback_longitude REAL,
  effective_latitude REAL,
  effective_longitude REAL,
  exif_extracted INTEGER NOT NULL DEFAULT 0,
  location_warning INTEGER NOT NULL DEFAULT 0,
  created_at_utc TEXT NOT NULL,
  FOREIGN KEY(series_id) REFERENCES adhoc_photo_series(id) ON DELETE CASCADE
)
''',
  'CREATE INDEX IF NOT EXISTS idx_adhoc_photo_series_event_id ON adhoc_photo_series(event_id)',
  'CREATE INDEX IF NOT EXISTS idx_adhoc_series_photos_series_id ON adhoc_series_photos(series_id)',
  'CREATE INDEX IF NOT EXISTS idx_adhoc_series_photos_created_at ON adhoc_series_photos(created_at_utc)',
];

const List<List<String>> kFieldPackMigrations = <List<String>>[
  kFieldPackMigrationV1,
  kFieldPackMigrationV2,
];
