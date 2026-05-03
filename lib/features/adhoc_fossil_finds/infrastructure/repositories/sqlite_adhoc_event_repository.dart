import 'package:sqlite3/sqlite3.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_collection_event.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/repositories/adhoc_event_repository.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_database.dart';

part 'sqlite_adhoc_event_repository_helpers.dart';

class SqliteAdhocEventRepository implements AdhocEventRepository {
  SqliteAdhocEventRepository(this._database);

  final FieldPackDatabase _database;

  @override
  Future<void> saveCollectionEvent(AdhocCollectionEvent event) {
    return _withDatabase<void>((db) {
      _upsertEvent(db, event);
    });
  }

  @override
  Future<AdhocCollectionEvent?> getCollectionEventById(String eventId) {
    return _withDatabase<AdhocCollectionEvent?>((db) {
      final eventRows = db.select(
        '''
SELECT id, name, created_at_utc, updated_at_utc
FROM adhoc_collection_events
WHERE id = ?
LIMIT 1
''',
        <Object?>[eventId],
      );
      if (eventRows.isEmpty) {
        return null;
      }

      final series = _loadSeriesForEvent(db, eventId);
      return _mapEvent(eventRows.first, series);
    });
  }

  @override
  Future<List<AdhocCollectionEvent>> listCollectionEvents() {
    return _withDatabase<List<AdhocCollectionEvent>>((db) {
      final eventRows = db.select('''
SELECT id, name, created_at_utc, updated_at_utc
FROM adhoc_collection_events
ORDER BY created_at_utc DESC
''');

      final events = <AdhocCollectionEvent>[];
      for (final row in eventRows) {
        final eventId = row['id'] as String;
        final series = _loadSeriesForEvent(db, eventId);
        events.add(_mapEvent(row, series));
      }
      return events;
    });
  }

  @override
  Future<void> deleteCollectionEvent(String eventId) {
    return _withDatabase<void>((db) {
      db.execute('DELETE FROM adhoc_collection_events WHERE id = ?', <Object?>[
        eventId,
      ]);
    });
  }

  @override
  Future<void> savePhotoSeries(AdhocPhotoSeries series) {
    return _withDatabase<void>((db) {
      _upsertSeries(db, series);
    });
  }

  @override
  Future<List<AdhocPhotoSeries>> listPhotoSeries(String eventId) {
    return _withDatabase<List<AdhocPhotoSeries>>((db) {
      return _loadSeriesForEvent(db, eventId);
    });
  }

  @override
  Future<void> deletePhotoSeries(String seriesId) {
    return _withDatabase<void>((db) {
      db.execute('DELETE FROM adhoc_photo_series WHERE id = ?', <Object?>[
        seriesId,
      ]);
    });
  }

  @override
  Future<void> saveSeriesPhoto(AdhocSeriesPhoto photo) {
    return _withDatabase<void>((db) {
      _upsertPhoto(db, photo);
      _touchEventBySeriesId(db, photo.seriesId);
    });
  }

  @override
  Future<List<AdhocSeriesPhoto>> listSeriesPhotos(String seriesId) {
    return _withDatabase<List<AdhocSeriesPhoto>>((db) {
      return _loadPhotosForSeries(db, seriesId);
    });
  }

  @override
  Future<void> saveCapturedPhotoTransaction({
    required AdhocCollectionEvent event,
    required AdhocPhotoSeries series,
    required AdhocSeriesPhoto photo,
  }) {
    return _withDatabase<void>((db) {
      db.execute('BEGIN TRANSACTION');
      try {
        _upsertEvent(db, event);
        _upsertSeries(db, series);
        _upsertPhoto(db, photo);
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
  }

  Future<T> _withDatabase<T>(T Function(Database db) operation) async {
    final db = await _database.open();
    try {
      return operation(db);
    } finally {
      db.dispose();
    }
  }
}
