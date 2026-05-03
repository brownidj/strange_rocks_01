import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_collection_event.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';

abstract interface class AdhocEventRepository {
  Future<void> saveCollectionEvent(AdhocCollectionEvent event);
  Future<AdhocCollectionEvent?> getCollectionEventById(String eventId);
  Future<List<AdhocCollectionEvent>> listCollectionEvents();
  Future<void> deleteCollectionEvent(String eventId);

  Future<void> savePhotoSeries(AdhocPhotoSeries series);
  Future<List<AdhocPhotoSeries>> listPhotoSeries(String eventId);
  Future<void> deletePhotoSeries(String seriesId);

  Future<void> saveSeriesPhoto(AdhocSeriesPhoto photo);
  Future<List<AdhocSeriesPhoto>> listSeriesPhotos(String seriesId);

  Future<void> saveCapturedPhotoTransaction({
    required AdhocCollectionEvent event,
    required AdhocPhotoSeries series,
    required AdhocSeriesPhoto photo,
  });
}
