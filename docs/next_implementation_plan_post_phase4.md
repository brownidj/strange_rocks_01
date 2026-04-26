# Next Implementation Plan (Post Phase 4)

## Context
Phases 1-4 established the field-pack foundation (pack definition/import, download pipeline, validation, lifecycle states, hardening checks, and initial UI).

Based on `docs/fossil_field_app_offline_design.md`, the next major gap is the **core field-capture workflow**: offline map use, fossil find recording, geology context lookup, and post-fieldwork export/sync.

## Current Gaps vs Design
- No offline map screen with location dot + GPS uncertainty circle.
- No find-capture data model (`finds`, `photos`, `locations`, `sync_queue`, etc.).
- No geology context lookup from offline layers at record time.
- No record-find UI (photos, notes, context flags, confidence).
- No sync/export workflow.
- No reviewer/admin integration contract.

## Proposed Next Roadmap

### Phase 5 - Offline Map and Positioning (MVP Map)
Goal: Make field packs usable in-field for navigation and capture context.

Scope:
- Add `Map` feature module with UI/domain/infra separation.
- Render offline basemap from pack assets (`mbtiles` path from active pack).
- Show device location and GPS accuracy radius.
- Add GPS quality status messaging (`Good/Acceptable/Poor/Very poor`).
- Add “active field pack boundary” overlay (from `field_area.geojson`).

Deliverables:
- `MapScreen` with current location and accuracy circle.
- `LocationService` abstraction for GPS stream.
- Map state controller and unit/widget tests.

Acceptance:
- Works in airplane mode with active pack.
- Map renders without network access.
- GPS accuracy warning changes by threshold.

### Phase 6 - Record Find Workflow (Core Domain)
Goal: Capture scientifically useful fossil-find records offline.

Scope:
- Add SQLite schema v2 for:
  - `finds`
  - `find_photos`
  - `find_locations`
  - `sync_queue`
- Create `RecordFindUseCase` and repository.
- Capture fields from design doc:
  - coordinates, horizontal accuracy, timestamps, notes
  - context flag (`in_situ`, `loose`, `creek_gravel`, `spoil`, `unknown`)
  - user confidence
- Attach photos from camera/gallery with local path persistence.

Deliverables:
- `RecordFindScreen` and `FindDetailScreen`.
- Migration scripts + repository CRUD.
- Tests for migration, insert/update/delete, and validation rules.

Acceptance:
- User can save a complete record offline with 0+ photos.
- Records persist across restart.
- Required fields validated before save.

### Phase 7 - Geology Context and Uncertainty
Goal: Provide cautious geology interpretation at capture time.

Scope:
- Load geology polygons/attributes from pack data.
- At save time, compute:
  - mapped geology unit at GPS point
  - nearest mapped boundary distance
- Add explicit caution text (not definitive provenance claim).
- Store interpreted context in `finds`.

Deliverables:
- `GeologyContextService` abstraction.
- Context panel in `RecordFindScreen` and `FindDetailScreen`.
- Unit tests with fixture geometries.

Acceptance:
- Find record stores mapped unit + boundary distance.
- UI always includes uncertainty disclaimer language.

### Phase 8 - Export and Sync Foundation
Goal: Move collected records to downstream review systems.

Scope:
- Export package format (`json/csv + photos`) for offline handoff.
- Introduce sync client contract + queued sync state machine.
- Support retryable sync states: `pending`, `in_progress`, `failed`, `synced`.
- Add conflict-safe idempotent upload design (`find_id` stable UUID).

Deliverables:
- `ExportScreen` and `SyncScreen`.
- `SyncQueueService` and `ExportService`.
- Integration tests with fake server adapter.

Acceptance:
- User can export all unsynced records offline.
- Sync queue survives app restarts and retries failures.

### Phase 9 - Reviewer/Admin Contract
Goal: Prepare for expert validation workflow.

Scope:
- Define API/data contract for review statuses:
  - `verified`, `probable`, `uncertain`, `duplicate`, `rejected`
- Add local model support for reviewer feedback fields.
- Add sync ingestion path for remote review updates.

Deliverables:
- Reviewer contract doc + DTOs.
- Local schema extension for review metadata.
- Tests for round-trip serialization.

Acceptance:
- App can receive and display reviewer status on find records.

## Cross-Cutting Workstreams
- Testing:
  - Add iOS integration tests for map + record capture + export flow.
  - Add Android UI integration coverage (Patrol optional as noted in CURRENT_STATE).
- Performance:
  - Stress test with large packs and 5k+ records.
- Data safety:
  - Add optional encrypted photo storage and checksum validation for exported bundles.
- Observability:
  - Expand telemetry for map-load latency, save-failure rate, and sync outcomes.

## Suggested Execution Order
1. Phase 5 (Offline Map)
2. Phase 6 (Record Find)
3. Phase 7 (Geology Context)
4. Phase 8 (Export/Sync)
5. Phase 9 (Reviewer Contract)

## Immediate Next Sprint (2-week slice)
- Implement Phase 5 MVP map screen.
- Add GPS accuracy ring + quality labeling.
- Add navigation entry from field pack list to map.
- Add 1 integration test for airplane-mode map usage.

