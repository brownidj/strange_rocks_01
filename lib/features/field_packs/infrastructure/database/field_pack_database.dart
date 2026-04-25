import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_migrations.dart';

class FieldPackDatabase {
  FieldPackDatabase({Future<Directory> Function()? appSupportDirProvider})
    : _appSupportDirProvider =
          appSupportDirProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _appSupportDirProvider;

  Future<Database> open() async {
    final supportDir = await _appSupportDirProvider();
    final dbDir = Directory(p.join(supportDir.path, 'db'));
    await dbDir.create(recursive: true);

    final dbPath = p.join(dbDir.path, 'field_packs.db');
    final db = sqlite3.open(dbPath);

    _configure(db);
    _migrate(db);

    return db;
  }

  void _configure(Database db) {
    db.execute('PRAGMA foreign_keys = ON');
  }

  void _migrate(Database db) {
    db.execute(
      'CREATE TABLE IF NOT EXISTS schema_version(version INTEGER NOT NULL)',
    );

    final versionRow = db.select('SELECT version FROM schema_version LIMIT 1');
    final currentVersion = versionRow.isEmpty
        ? 0
        : versionRow.first['version'] as int;

    if (currentVersion > kFieldPackDbVersion) {
      throw StateError(
        'Database schema version $currentVersion is newer than supported $kFieldPackDbVersion',
      );
    }

    for (
      var version = currentVersion + 1;
      version <= kFieldPackDbVersion;
      version++
    ) {
      final migrationIndex = version - 1;
      if (migrationIndex >= kFieldPackMigrations.length) {
        throw StateError('No migration found for database version $version');
      }
      db.execute('BEGIN TRANSACTION');
      try {
        for (final statement in kFieldPackMigrations[migrationIndex]) {
          db.execute(statement);
        }
        db.execute('DELETE FROM schema_version');
        db.execute('INSERT INTO schema_version(version) VALUES (?)', [version]);
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }
}
