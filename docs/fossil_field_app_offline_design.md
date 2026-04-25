# Offline-First Fossil Find Recording App

## Project Purpose

This project is to create mobile software that allows laypersons to record possible fossil finds in the field. The app should use device capabilities such as GPS, camera, date, time, and possibly compass/bearing, but it must be designed for situations where the user is offline.

A major challenge is accurately recording and interpreting the location of a find. The app should help the user record the find location, understand the uncertainty around that location, and provide useful physical geography, geology, and stratigraphy context where possible.

The software will be written in Dart/Flutter to support both iOS and Android versions.

## Core Design Principle

This is a strong fit for an **offline-first geospatial field app**.

The key design decision is:

> Do not make the mobile app depend on live map, imagery, or geology services while the user is in the field.

Instead, the app should allow the user to prepare a defined field area while online, then store enough map, imagery, geology, and stratigraphy context locally so the collector can still record a find offline.

## Queensland Data Context

Queensland is a favourable jurisdiction for this type of project because geological and geospatial data are made available through government sources.

Relevant Queensland sources include:

- Queensland Government geological spatial datasets, including surface geology and regional geology layers.
- Geological Survey of Queensland open data resources.
- Downloadable GIS formats such as SHP, TAB, FGDB, KMZ, and GPKG.
- Geological polygons and line features such as boundaries, faults, bedding trends, dykes, folds, and related geological structures.
- OGC-style map services such as WMS for some datasets.

For an offline mobile app, downloadable vector data or prebuilt offline field packs will usually be more useful than live web services.

## Recommended User Workflow

### 1. Before Fieldwork: Online Preparation

Before going into the field, the user or project organiser defines a field area. This could be a polygon around:

- a property
- a reserve
- a creek line
- a road cutting
- a quarry area
- a known fossil-hunting locality
- a teaching or research field area

The app then downloads a **field pack** for that area.

A field pack could include:

- base map or topographic tiles
- optional satellite or orthophoto imagery, subject to licensing
- geology polygons
- faults, lineaments, and geological boundaries
- stratigraphic or geological unit attributes
- nearby named features, roads, watercourses, and contours
- a compact offline gazetteer for the selected area
- project-specific instructions and safety notes

### 2. During Fieldwork: Offline Recording

While offline, the app should allow the collector to record:

- GPS coordinate
- GPS accuracy radius
- date and time
- device compass or bearing, if useful
- photos
- user notes
- confidence level
- whether the find is in situ, loose, in creek gravel, in spoil, or uncertain
- local geology context looked up from the stored offline layers

The app should work even when there is no network connection.

### 3. After Fieldwork: Sync or Export

After returning online, the user can sync or export records.

A later expert reviewer should be able to check:

- the photos
- the recorded coordinates
- GPS accuracy
- mapped geology
- the user's field notes
- whether the fossil was found in situ, loose, transported, or in an uncertain context

## Important Geological Caution

The app can reasonably say:

> Your recorded location falls within mapped unit X, near boundary Y, and close to feature Z.

But it should avoid saying:

> This fossil comes from unit X.

That would be too strong unless the find is clearly in situ.

For layperson reporting, the wording should be cautious. For example:

> Mapped surface geology at this GPS location: [unit name]. This is an interpreted map layer and may not represent the exact source of a loose specimen.

This distinction matters because fossils may be:

- reworked
- transported downslope
- washed into creek beds
- moved in road fill
- collected from spoil
- found loose on the surface far from their original bedrock source

## Recommended System Architecture

The system should be separated into four broad layers.

## 1. Mobile Capture App

The mobile app should be built in Flutter/Dart for iOS and Android.

Its core responsibilities are to:

- record find data
- show a map and current position
- operate fully offline
- attach photos
- store local records safely
- display local geology and topography context
- sync or export when online

For mapping, consider:

- **MapLibre** for vector-tile-based maps and styling.
- **flutter_map** for a simpler Leaflet-like raster tile or MBTiles workflow.
- **MapKit or Google Maps** only as optional online convenience layers, not as the primary offline field system.

## 2. Field-Pack Builder

A field-pack builder should prepare selected areas for offline use.

This does not need to be built entirely inside the mobile app at first. A desktop or server-side preparation pipeline would be cleaner.

The field-pack builder would take a selected area and create a downloadable package containing relevant local data.

A field pack could contain:

```text
field_area.geojson
basemap.mbtiles
topography.mbtiles
geology.gpkg
stratigraphy.sqlite
metadata.json
licence.json
manifest.json
```

The app imports the field pack and can then operate offline within that area.

This keeps the mobile app simpler and avoids asking the phone to process large GIS datasets directly.

## 3. Local Spatial Database

On the device, use SQLite.

For an early version, plain SQLite plus stored GeoJSON may be enough. Later, if stronger spatial querying is needed, the app can add a more formal spatial indexing approach.

Recommended local tables include:

- `finds`
- `photos`
- `locations`
- `field_areas`
- `geology_units`
- `geology_boundaries`
- `stratigraphic_units`
- `sync_queue`

Each find should store both the raw GPS value and the interpreted context.

Example fields:

```text
find_id
latitude
longitude
horizontal_accuracy_m
altitude
altitude_accuracy_m
timestamp_device
timestamp_utc
field_area_id
mapped_geology_unit_id
distance_to_nearest_boundary_m
location_confidence
geological_context_confidence
is_in_situ
user_notes
review_status
```

The distance to the nearest geological boundary is particularly important. A fossil recorded 5 metres from a mapped unit boundary should be treated with less confidence than one recorded 800 metres inside a mapped polygon.

## 4. Review/Admin System

For citizen-science or layperson fossil records, the mobile app should not be the only part of the system.

A later review interface would allow a palaeontologist, geologist, curator, or project organiser to:

- inspect photos
- check GPS accuracy
- view mapped geology
- flag doubtful locations
- request more information
- mark the record as verified, probable, uncertain, duplicate, or rejected

This could be a later web app, but the data model should anticipate it from the beginning.

## Physical Geography and Imagery

Satellite imagery can be helpful, but licensing and offline use are the main complications.

For the first version, a good topographic base map may be more useful than satellite imagery.

Collectors often need to identify:

- creek beds
- gullies
- ridges
- road cuttings
- tracks
- property boundaries
- elevation and slope
- nearby landmarks

Satellite or aerial imagery is useful only if:

- the source licence allows offline caching or redistribution
- the storage requirements are manageable
- the resolution is useful for the selected field area

A compact elevation model or derived topographic layer could be very valuable. It could support:

- contours
- hillshade
- slope
- drainage context
- elevation at the find location

In many cases, topography and drainage context may be more scientifically useful than generic satellite imagery.

## Location Accuracy Design

The app should not store only a point. It should store a **point plus uncertainty**.

In the user interface, show:

- a dot for the estimated GPS location
- a circle for the GPS accuracy radius
- a warning if accuracy is poor

Example message:

> GPS accuracy: ±18 m. Geology lookup is approximate.

A simple rating system could be:

| Accuracy | Interpretation |
|---|---|
| ≤ 5 m | Good |
| 5–15 m | Acceptable |
| 15–50 m | Poor |
| > 50 m | Very poor |

The app should encourage the user to wait for better GPS accuracy before saving, especially if the device reports poor accuracy.

The app should also ask a simple geological context question:

> Was the fossil found in rock, loose on the surface, in creek gravel, in a road cutting, in spoil, or unknown?

That question may be more scientifically valuable than automatically assigning the find to the mapped geology unit.

## Suggested Minimum Viable Product

The first serious prototype should not try to cover all of Queensland.

A good MVP would support one predefined Queensland test area.

### Field Pack

The field pack should include:

- offline basemap tiles
- geology polygons
- geology unit attributes
- basic topographic context
- a simple stratigraphy lookup table

### Mobile App Screens

The app could have these screens:

1. **Field Area screen**  
   Shows downloaded field packs and whether they are ready for offline use.

2. **Map screen**  
   Shows current location, offline map, geology overlay, and GPS accuracy circle.

3. **Record Find screen**  
   Lets the user add photos, notes, find type, context, and save the record.

4. **Geology Context screen**  
   Shows mapped unit, unit description, age, lithology, nearest boundary distance, and uncertainty warning.

5. **Sync/Export screen**  
   Exports records as JSON/CSV plus photos, or syncs them when online.

## Suggested Geology Context Data Model

For each geological polygon, store fields such as:

```text
unit_id
unit_name
map_symbol
age
period
epoch
lithology
description
source_dataset
source_scale
source_date
confidence
```

When the user saves a find, store a snapshot of the interpreted geological context:

```text
find_id
mapped_unit_id
mapped_unit_name
mapped_unit_age
mapped_unit_lithology
distance_to_boundary_m
geology_lookup_method
geology_source_scale
```

Store the snapshot, not just a foreign key. That way, if the geology database is updated later, the original interpretation remains auditable.

## Suggested Flutter Implementation Stack

A reasonable implementation stack would be:

```text
Flutter/Dart mobile app
    |
    |-- MapLibre or flutter_map for map display
    |-- SQLite for local records
    |-- MBTiles for offline basemap/topography
    |-- GeoPackage/GeoJSON-derived SQLite tables for geology
    |-- device GPS, camera, compass, and timestamp services
    |-- sync/export service
```

Packages and concepts to investigate include:

- `maplibre` or `flutter-maplibre-gl`
- `flutter_map`
- MBTiles
- SQLite
- GeoJSON
- simplified vector tiles for geology overlays
- field-pack manifest files

## Strong Recommendation

Do not start by trying to build a general Queensland-wide geology and satellite imagery app.

Start with this smaller goal:

> A user can download one predefined field area while online, go offline, see their position on a map, record a possible fossil with photos and notes, and receive a cautious local geology/context summary based on stored offline layers.

That gives the project real scientific and technical value without overbuilding.

The app's distinctive strength should not simply be that it shows maps. Many apps do that.

Its distinctive strength should be:

> It records fossil finds with location uncertainty, photographic evidence, field context, offline capability, and geologically informed metadata suitable for later expert review.
