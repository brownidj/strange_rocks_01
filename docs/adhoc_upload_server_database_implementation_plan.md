# Adhoc Upload Server + Database Implementation Plan

## Goal
Create and run a local backend service on this machine so the mobile app can upload completed adhoc fossil events, and persist uploaded data in a local database.

## Scope
- Build a new upload API service under `scripts/backend/` (same backend stack already used in this repo).
- Create a server-side SQLite database dedicated to uploaded adhoc data.
- Support upload of:
  - event metadata
  - series metadata
  - photo metadata
  - photo binary files
- Add a local run workflow for development and device testing.

## Proposed Stack (Aligned to Existing Repo)
- Language/runtime: Dart (`dart run ...`) for backend scripts.
- HTTP server: `dart:io` `HttpServer` (consistent with `field_pack_backend_server.dart`).
- Database: SQLite file on local disk.
- File storage: local directory for uploaded photos.

## Implementation Architecture
- New backend entrypoint: `scripts/backend/adhoc_upload_server.dart`
- New service/router: `scripts/backend/adhoc_upload_service.dart`
- New database module: `scripts/backend/adhoc_upload_db.dart`
- New shared models/DTOs: `scripts/backend/adhoc_upload_models.dart`
- New storage area:
  - DB file: `build/local_backend/adhoc_uploads.db`
  - Photo root: `build/local_backend/uploads/`

## API Contract (MVP)

### 1) Health
- `GET /healthz`
- Response: `{ "status": "ok" }`

### 2) Upload Completed Event
- `POST /v1/adhoc/events/upload`
- Request: `multipart/form-data`
  - Part `payload`: JSON with event/series/photo metadata
  - Parts `file_<photo_id>`: image binaries referenced by metadata
- Response: `201 Created`
  - `{ "server_event_id": "...", "uploaded_photo_count": N, "received_at_utc": "..." }`

### 3) Upload Status by Client Event ID
- `GET /v1/adhoc/events/:client_event_id/status`
- Response: `{ "exists": true|false, "server_event_id": "..." }`

### 4) Basic Admin List (local debugging)
- `GET /v1/adhoc/events?limit=50`
- Response: list of uploaded events and counts

## Client Payload Shape (Draft)
- `client_event_id` (UUID from app)
- `event_name`
- `event_created_at_utc`
- `event_updated_at_utc`
- `uploaded_at_utc`
- `series[]`
  - `client_series_id`
  - `title`
  - `started_at_utc`
  - `ended_at_utc`
  - `anchor_latitude`
  - `anchor_longitude`
  - `max_radius_meters`
  - `location_incomplete`
  - `photos[]`
    - `client_photo_id`
    - `captured_at_utc`
    - `created_at_utc`
    - `effective_latitude`
    - `effective_longitude`
    - `metadata_latitude`
    - `metadata_longitude`
    - `fallback_latitude`
    - `fallback_longitude`
    - `exif_extracted`
    - `location_warning`
    - `file_name`
    - `sha256`
    - `size_bytes`

## Database Design (Server-Side SQLite)

### Tables
- `upload_events`
  - `id` TEXT PK (server UUID)
  - `client_event_id` TEXT UNIQUE NOT NULL
  - `event_name` TEXT NOT NULL
  - `event_created_at_utc` TEXT NOT NULL
  - `event_updated_at_utc` TEXT NOT NULL
  - `uploaded_at_utc` TEXT NOT NULL
  - `received_at_utc` TEXT NOT NULL
- `upload_series`
  - `id` TEXT PK
  - `event_id` TEXT NOT NULL FK -> `upload_events(id)` ON DELETE CASCADE
  - `client_series_id` TEXT NOT NULL
  - `title` TEXT NOT NULL
  - `started_at_utc` TEXT NOT NULL
  - `ended_at_utc` TEXT NULL
  - `anchor_latitude` REAL NULL
  - `anchor_longitude` REAL NULL
  - `max_radius_meters` REAL NOT NULL
  - `location_incomplete` INTEGER NOT NULL
  - UNIQUE(`event_id`, `client_series_id`)
- `upload_photos`
  - `id` TEXT PK
  - `series_id` TEXT NOT NULL FK -> `upload_series(id)` ON DELETE CASCADE
  - `client_photo_id` TEXT NOT NULL
  - `captured_at_utc` TEXT NULL
  - `created_at_utc` TEXT NOT NULL
  - `effective_latitude` REAL NULL
  - `effective_longitude` REAL NULL
  - `metadata_latitude` REAL NULL
  - `metadata_longitude` REAL NULL
  - `fallback_latitude` REAL NULL
  - `fallback_longitude` REAL NULL
  - `exif_extracted` INTEGER NOT NULL
  - `location_warning` INTEGER NOT NULL
  - `file_name` TEXT NOT NULL
  - `stored_path` TEXT NOT NULL
  - `sha256` TEXT NOT NULL
  - `size_bytes` INTEGER NOT NULL
  - UNIQUE(`series_id`, `client_photo_id`)

### Indexes
- `idx_upload_events_uploaded_at` on `upload_events(uploaded_at_utc)`
- `idx_upload_series_event_id` on `upload_series(event_id)`
- `idx_upload_photos_series_id` on `upload_photos(series_id)`

## Upload Flow
1. Client finalizes event and builds upload payload.
2. Client sends multipart request with payload JSON + image files.
3. Server validates:
- required IDs and timestamps
- payload/file correspondence
- max file size and mime type
- SHA-256 checksum per file
4. Server writes files to `build/local_backend/uploads/<server_event_id>/...`.
5. Server commits metadata in a single DB transaction.
6. Server returns server IDs + counts.

## Idempotency and Conflict Rules
- Primary client identity: `client_event_id`.
- If `client_event_id` already exists:
  - same payload hash: return `200` with existing record (idempotent success)
  - different payload hash: return `409 Conflict` with reason.
- This prevents accidental duplicate uploads from retries.

## Security and Operational Guardrails (Local MVP)
- Bind to `127.0.0.1` by default.
- Configurable port via env var `ADHOC_UPLOAD_BACKEND_PORT`.
- Restrict accepted file types (`image/jpeg`, `image/png`, optionally `image/heic`).
- Enforce request size limit and per-file size limit.
- Redact file paths in logs.

## Runbook (Local)

### 1) Start server
```bash
ADHOC_UPLOAD_BACKEND_PORT=8090 dart run scripts/backend/adhoc_upload_server.dart
```

### 2) Point app to local backend (Android emulator example)
```bash
flutter run \
  --dart-define=ADHOC_UPLOAD_BACKEND_BASE_URL=http://10.0.2.2:8090
```

### 3) Verify
- `GET /healthz` responds `200`.
- Upload a completed event from app.
- Confirm rows exist in SQLite DB and files exist in upload folder.

## App Integration Plan
- Add new upload client in app:
  - `lib/features/adhoc_fossil_finds/infrastructure/api/http_adhoc_upload_api_client.dart`
- Add `--dart-define` base URL:
  - `ADHOC_UPLOAD_BACKEND_BASE_URL` (default `http://127.0.0.1:8090`)
- Trigger upload on “Finish event” path after final local validation passes.
- Persist upload status locally (`pending`, `uploading`, `uploaded`, `failed`) in future migration.

## Phased Delivery

### Phase 1: Server skeleton + health + DB bootstrap
- Implement server startup and `/healthz`.
- Initialize SQLite schema and directories.
- Add basic logging and config parsing.

### Phase 2: Upload endpoint + file persistence
- Implement `POST /v1/adhoc/events/upload`.
- Parse multipart payload and files.
- Validate and write transactionally.

### Phase 3: Status/list endpoints + idempotency
- Implement status lookup and event listing.
- Add duplicate detection and conflict handling.

### Phase 4: App wiring + end-to-end smoke test
- Add mobile upload API client.
- Wire finish flow to server upload.
- Verify with real captured photos and emulator/device networking.

## Step-by-Step Implementation Plan (Code Execution Order)
1. Create backend files:
- Add `scripts/backend/adhoc_upload_server.dart`.
- Add `scripts/backend/adhoc_upload_service.dart`.
- Add `scripts/backend/adhoc_upload_db.dart`.
- Add `scripts/backend/adhoc_upload_models.dart`.

2. Implement config + boot:
- Read `ADHOC_UPLOAD_BACKEND_PORT` (default `8090`).
- Resolve/create `build/local_backend/` and upload directory.
- Bind server to `127.0.0.1`.

3. Implement SQLite bootstrap in `adhoc_upload_db.dart`:
- Open/create `build/local_backend/adhoc_uploads.db`.
- Enable `PRAGMA foreign_keys = ON`.
- Create `upload_events`, `upload_series`, `upload_photos`, and indexes.
- Add a simple migration/version table for future schema changes.

4. Implement request routing in `adhoc_upload_service.dart`:
- `GET /healthz`.
- `POST /v1/adhoc/events/upload`.
- `GET /v1/adhoc/events/:client_event_id/status`.
- `GET /v1/adhoc/events?limit=...`.

5. Implement DTO parsing in `adhoc_upload_models.dart`:
- Add typed request models for event/series/photo metadata.
- Add `fromJson` parsing + validation errors.
- Enforce required fields and basic type checks.

6. Implement multipart upload parsing:
- Parse `payload` JSON part.
- Parse `file_<photo_id>` parts into temp files or memory buffers.
- Validate that every metadata photo has a matching file.

7. Implement upload validation rules:
- Allowed mime types (`image/jpeg`, `image/png`, optional `image/heic`).
- Max request size and per-file size.
- SHA-256 checksum and byte-length verification against payload.
- Reject malformed timestamps/IDs with `400`.

8. Implement transactional persistence:
- Create `server_event_id` and `received_at_utc`.
- Write image files to `build/local_backend/uploads/<server_event_id>/`.
- In a DB transaction, insert event -> series -> photos.
- On any failure, rollback DB and remove partially written files.

9. Implement idempotency behavior:
- Lookup by `client_event_id`.
- If not found: insert normally and return `201`.
- If found with same payload hash: return `200` with existing IDs/counts.
- If found with different payload hash: return `409 Conflict`.

10. Implement status/list endpoints:
- `status`: return existence + `server_event_id`.
- `events`: paginated list with series/photo counts for local inspection.

11. Add app-side upload API client:
- Create `lib/features/adhoc_fossil_finds/infrastructure/api/http_adhoc_upload_api_client.dart`.
- Build multipart request payload from existing adhoc repository entities.
- Add environment base URL `ADHOC_UPLOAD_BACKEND_BASE_URL`.

12. Wire upload to finish flow:
- Hook into the “Finish event” completion path.
- Trigger upload only after local validation succeeds.
- Surface upload result/failure messages in controller + UI.

13. Add tests:
- Unit tests for JSON parsing/validation/checksums/idempotency.
- Integration tests for upload endpoint and DB writes.
- App-level test for finish->upload success/failure state handling.

14. Run local end-to-end verification:
- Start server.
- Run app with backend define.
- Finish an event with photos.
- Confirm DB rows and file persistence under `build/local_backend/uploads/`.

## Testing Plan
- Unit tests:
  - payload validation
  - checksum verification
  - idempotency rules
  - schema creation
- Integration tests:
  - multipart upload happy path
  - missing file mismatch
  - conflict retry scenario
- Manual smoke test:
  - finish event in app and confirm DB + files on disk.

## Definition of Done
- Local server can be started with one command.
- App can upload at least one completed event with photos.
- Metadata is queryable from SQLite database.
- Uploaded photo binaries are persisted and linked in DB.
- Retrying the same event is idempotent (no duplicates).
