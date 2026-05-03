# Adhoc Fossil Finds: Implementation Outline

## Purpose
Define how to implement `Adhoc fossil finds` so a user can create a named collection event, capture photos in one or more series, and associate each series with location data.

## Functional Requirements
1. A collection event has a user-provided name.
2. A collection event must include at least 1 photo series.
3. Each series contains between 1 and 20 photos (inclusive).
4. Each series has a title based on date/time (auto-generated).
5. Series photos should be within 50 m of each other.
6. Additional series can be created manually.
7. A new series can be created automatically if location moves more than 50 m.
8. GPS should come from photo metadata when available; otherwise capture location separately.

## Suggested Data Model

### CollectionEvent
- `id` (UUID)
- `name` (string, non-empty)
- `createdAtUtc` (DateTime)
- `updatedAtUtc` (DateTime)
- `series` (List<PhotoSeries>)

### PhotoSeries
- `id` (UUID)
- `eventId` (UUID)
- `title` (string, generated from local date/time, format `yyyy-MM-dd HH:mm.ss`, e.g. `2026-05-01 14:32.08`)
- `startedAtUtc` (DateTime)
- `endedAtUtc` (DateTime)
- `anchorLocation` (LatLng?)
- `maxRadiusMeters` (double, computed)
- `photos` (List<SeriesPhoto>)

### SeriesPhoto
- `id` (UUID)
- `seriesId` (UUID)
- `filePath` (string)
- `capturedAtUtc` (DateTime?)
- `metadataLocation` (LatLng?)
- `fallbackLocation` (LatLng?)
- `effectiveLocation` (LatLng?)  // metadata first, fallback second
- `exifExtracted` (bool)

## Location Rules
1. For each photo, attempt EXIF GPS extraction first.
2. If EXIF GPS missing, request current device location and store as fallback location.
3. `effectiveLocation = metadataLocation ?? fallbackLocation`.
4. For series distance checks, only use photos with `effectiveLocation`.
5. If no photo in a series has location, allow save but mark series as `location_incomplete` for follow-up.

## Series Boundary Rules

### Manual Boundary
- User can tap `Start new series` anytime.
- Current series closes; next captured photo starts a new series.

### Automatic Boundary
- If current series has an anchor location and the next photo location is > 50 m from anchor, start a new series automatically.
- New series anchor becomes the new photo location.
- Show non-blocking message: `New series started (moved > 50 m).`

### Distance Validation Within Series
- Preferred anchor: first photo with location in the series.
- On each additional located photo:
  - Compute distance from anchor.
  - If `<= 50 m`: keep in current series.
  - If `> 50 m`: auto-start next series and place photo there.

## Photo Count Rules
1. Minimum per series: 1 photo.
2. Maximum per series: 20 photos.
3. When photo 20 is reached:
   - Next capture starts a new series automatically.
   - Show message: `Series limit reached (20). Started a new series.`
4. Block saving event if any series has 0 photos.

## UI/UX Proposal

### Adhoc Fossil Finds Home
- `Collection event name` text field.
- List of series cards.
- Primary actions:
  - `Add photo`
  - `Start new series`
  - `Finish event`

### Series Card
- Title (date/time)
- Photo count (e.g. `7/20`)
- Location status (`GPS from photo`, `GPS from device`, `Missing GPS`)
- Radius summary (e.g. `Max spread: 34 m`)
- Thumbnail strip/grid

### Capture Flow
1. Ensure event exists (prompt for name if not yet set).
2. Capture/select photo.
3. Parse EXIF.
4. Resolve effective location.
5. Apply boundary rules (50 m / 20-photo cap).
6. Append photo to active/new series.

## Technical Approach in Flutter

## Dependencies
- `image_picker` for capture/selection.
- `exif` (or equivalent) for metadata GPS extraction.
- `geolocator` for fallback device location.
- `path_provider` already available for persistent storage paths.

## Services
- `PhotoMetadataService`
  - Reads EXIF GPS + timestamp.
- `LocationFallbackService`
  - Handles permission and current location retrieval.
- `SeriesAssignmentService`
  - Applies 50 m and 20-photo rules.
- `AdhocEventRepository`
  - Persists events/series/photo metadata (SQLite recommended for consistency with existing architecture).

## Distance Computation
Use Haversine (meters) or geolocator distance utility. Keep one shared implementation and unit-test it heavily.

## Edge Cases
1. Permissions denied for location: still allow capture; mark `location_incomplete`.
2. EXIF exists but invalid values: treat as missing.
3. Indoor/poor GPS accuracy: optionally ignore fallback if accuracy > threshold (e.g. 50 m).
4. Clock mismatch in EXIF: title should still be generated from app-local current time when series starts.
5. User deletes all photos in a series: prevent event completion until series removed or a photo is added.

## Persistence Strategy
1. Store original image files in app documents directory under `adhoc_events/{eventId}/`.
2. Persist metadata separately in SQLite:
   - event, series, photo tables.
3. Store only file paths and metadata in DB, not raw image bytes.

## Validation Before Event Completion
- Event name non-empty.
- At least 1 series exists.
- Every series has 1..20 photos.
- Soft warning for missing location data; completion is still allowed.

## Confirmed Product Decisions
1. Photos with no location are allowed; show a warning.
2. Users cannot move photos between series.
3. Series title format is `yyyy-MM-dd HH:mm.ss`.
4. Export/share format is deferred to a later phase.

## Step-by-Step Implementation Plan
1. Create domain entities for adhoc events.
   - Add `AdhocCollectionEvent`, `AdhocPhotoSeries`, `AdhocSeriesPhoto`, and `LatLng` value objects.
   - Encode constraints in constructors or validators (series count/photo limits).
2. Add SQLite schema + migrations.
   - Create tables for events, series, photos.
   - Include location columns (`metadata_lat/lng`, `fallback_lat/lng`, `effective_lat/lng`) and warning flags.
3. Implement repository layer.
   - Add CRUD for event/series/photo records.
   - Add transactional save for `capture photo -> assign series -> persist`.
4. Implement capture + metadata services.
   - `PhotoCaptureService` for camera/gallery image intake.
   - `PhotoMetadataService` for EXIF timestamp + GPS extraction.
   - Store image files under `adhoc_events/{eventId}/`.
5. Implement fallback location service.
   - Request permission and current location only when EXIF GPS is missing.
   - Persist warning if no effective location could be resolved.
6. Implement series assignment engine.
   - Input: active series, new photo metadata/location.
   - Rules: max 20 photos, 50 m threshold auto-split, manual split support.
   - Title generation format: `yyyy-MM-dd HH:mm.ss`.
7. Build controller/state for adhoc flow.
   - Manage active event lifecycle, active series, and warning messages.
   - Expose actions: `startEvent`, `addPhoto`, `startNewSeries`, `finishEvent`.
8. Replace placeholder adhoc screen with functional UI.
   - Event name input, series cards, add photo button, new series button, finish event button.
   - Show per-photo/per-series warnings for missing location.
9. Enforce completion validation.
   - Ensure event name exists.
   - Ensure at least one series and each series has 1..20 photos.
   - Allow completion with location warnings.
10. Add unit tests.
   - 50 m split boundary (`49.9 m`, `50.0 m`, `50.1 m`).
   - 20-photo cap and 21st photo auto-new-series.
   - GPS precedence (`EXIF > fallback > missing warning`).
11. Add widget tests.
   - Cannot finish invalid event.
   - Manual `Start new series` behavior.
   - Warning rendering for missing location.
12. Run verification gate.
   - `flutter analyze`
   - targeted unit/widget tests for adhoc module
   - manual smoke test on device/emulator with and without location permission.

## Suggested Delivery Phases
1. Data model + repository + migrations.
2. Basic adhoc screen with event name + series list.
3. Photo capture and storage.
4. EXIF extraction and fallback GPS.
5. Series auto-split logic (50 m and 20 cap).
6. Validation and finish flow.
7. Tests + polish.

## Testing Plan

### Unit Tests
- Series assignment logic around 50 m threshold.
- Auto-split when 21st photo arrives.
- Effective location resolution precedence (EXIF over fallback).

### Widget Tests
- Event cannot finish without valid series.
- Manual `Start new series` behavior.
- Proper counters and messages shown.

### Integration/Manual Tests
- Capture with EXIF GPS present.
- Capture with no EXIF GPS and location permission granted.
- Capture with location denied.
- Walk >50 m and verify auto-series split.

## Open Decisions Before Build
1. Should `HH:mm.ss` use local device time only, or be stored alongside timezone metadata for audit?
2. Should distance checks reject low-accuracy GPS fixes (for example accuracy worse than 50 m), or always accept them with warning?
