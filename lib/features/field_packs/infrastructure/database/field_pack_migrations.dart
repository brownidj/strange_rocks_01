const int kFieldPackDbVersion = 1;

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

const List<List<String>> kFieldPackMigrations = <List<String>>[
  kFieldPackMigrationV1,
];
