import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class AdhocUploadDb {
  AdhocUploadDb({required this.backendRootDir})
    : dbPath = p.join(backendRootDir.path, 'adhoc_uploads.db');

  static const int _schemaVersion = 2;

  final Directory backendRootDir;
  final String dbPath;

  Future<void> ensureInitialized() async {
    await backendRootDir.create(recursive: true);
    final db = sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA foreign_keys = ON');
      _migrate(db);
    } finally {
      db.dispose();
    }
  }

  Database open() {
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA foreign_keys = ON');
    return db;
  }

  void _migrate(Database db) {
    db.execute(
      '''
CREATE TABLE IF NOT EXISTS adhoc_upload_schema_version (
  version INTEGER NOT NULL
)
''',
    );

    final rows = db.select(
      'SELECT version FROM adhoc_upload_schema_version LIMIT 1',
    );
    final currentVersion = rows.isEmpty ? 0 : rows.first['version'] as int;
    if (currentVersion > _schemaVersion) {
      throw StateError(
        'Database schema version $currentVersion is newer than supported $_schemaVersion',
      );
    }

    for (var version = currentVersion + 1; version <= _schemaVersion; version++) {
      final migration = _migrationFor(version);
      db.execute('BEGIN TRANSACTION');
      try {
        for (final statement in migration) {
          db.execute(statement);
        }
        db.execute('DELETE FROM adhoc_upload_schema_version');
        db.execute(
          'INSERT INTO adhoc_upload_schema_version(version) VALUES (?)',
          <Object?>[version],
        );
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }

  List<String> _migrationFor(int version) {
    switch (version) {
      case 1:
        return _migrationV1;
      case 2:
        return _migrationV2;
    }
    throw StateError('No migration found for schema version $version');
  }
}

const List<String> _migrationV1 = <String>[
  '''
CREATE TABLE IF NOT EXISTS upload_events (
  id TEXT PRIMARY KEY,
  client_event_id TEXT NOT NULL UNIQUE,
  event_name TEXT NOT NULL,
  event_created_at_utc TEXT NOT NULL,
  event_updated_at_utc TEXT NOT NULL,
  uploaded_at_utc TEXT NOT NULL,
  received_at_utc TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS upload_series (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  client_series_id TEXT NOT NULL,
  title TEXT NOT NULL,
  started_at_utc TEXT NOT NULL,
  ended_at_utc TEXT,
  anchor_latitude REAL,
  anchor_longitude REAL,
  max_radius_meters REAL NOT NULL,
  location_incomplete INTEGER NOT NULL,
  FOREIGN KEY(event_id) REFERENCES upload_events(id) ON DELETE CASCADE,
  UNIQUE(event_id, client_series_id)
)
''',
  '''
CREATE TABLE IF NOT EXISTS upload_photos (
  id TEXT PRIMARY KEY,
  series_id TEXT NOT NULL,
  client_photo_id TEXT NOT NULL,
  captured_at_utc TEXT,
  created_at_utc TEXT NOT NULL,
  effective_latitude REAL,
  effective_longitude REAL,
  metadata_latitude REAL,
  metadata_longitude REAL,
  fallback_latitude REAL,
  fallback_longitude REAL,
  exif_extracted INTEGER NOT NULL,
  location_warning INTEGER NOT NULL,
  file_name TEXT NOT NULL,
  stored_path TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  FOREIGN KEY(series_id) REFERENCES upload_series(id) ON DELETE CASCADE,
  UNIQUE(series_id, client_photo_id)
)
''',
  '''
CREATE INDEX IF NOT EXISTS idx_upload_events_uploaded_at
ON upload_events(uploaded_at_utc)
''',
  '''
CREATE INDEX IF NOT EXISTS idx_upload_series_event_id
ON upload_series(event_id)
''',
  '''
CREATE INDEX IF NOT EXISTS idx_upload_photos_series_id
ON upload_photos(series_id)
''',
];

const List<String> _migrationV2 = <String>[
  '''
ALTER TABLE upload_events
ADD COLUMN payload_sha256 TEXT NOT NULL DEFAULT ''
''',
];
