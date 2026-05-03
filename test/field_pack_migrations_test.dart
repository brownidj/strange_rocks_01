import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_migrations.dart';

void main() {
  test('migration version aligns with migration list length', () {
    expect(kFieldPackMigrations.length, kFieldPackDbVersion);
  });

  test('v1 migration contains expected tables and indexes', () {
    final migrationSql = kFieldPackMigrationV1.join('\n');

    expect(migrationSql, contains('CREATE TABLE IF NOT EXISTS field_packs'));
    expect(
      migrationSql,
      contains('CREATE TABLE IF NOT EXISTS field_pack_assets'),
    );
    expect(migrationSql, contains('CREATE TABLE IF NOT EXISTS field_areas'));
    expect(migrationSql, contains('idx_field_packs_active'));
    expect(migrationSql, contains('idx_field_pack_assets_pack_id'));
    expect(migrationSql, contains('idx_field_areas_pack_id'));
  });

  test('v2 migration contains adhoc tables and indexes', () {
    final migrationSql = kFieldPackMigrationV2.join('\n');

    expect(
      migrationSql,
      contains('CREATE TABLE IF NOT EXISTS adhoc_collection_events'),
    );
    expect(
      migrationSql,
      contains('CREATE TABLE IF NOT EXISTS adhoc_photo_series'),
    );
    expect(
      migrationSql,
      contains('CREATE TABLE IF NOT EXISTS adhoc_series_photos'),
    );
    expect(migrationSql, contains('idx_adhoc_photo_series_event_id'));
    expect(migrationSql, contains('idx_adhoc_series_photos_series_id'));
    expect(migrationSql, contains('idx_adhoc_series_photos_created_at'));
  });
}
