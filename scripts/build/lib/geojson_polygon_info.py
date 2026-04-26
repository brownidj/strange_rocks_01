#!/usr/bin/env python3
import json
import math
import sys
from typing import Iterable, List, Tuple


def iter_rings(geom):
    gtype = geom.get("type")
    coords = geom.get("coordinates")
    if gtype == "Polygon":
        for ring in coords:
            yield ring
    elif gtype == "MultiPolygon":
        for poly in coords:
            for ring in poly:
                yield ring
    else:
        raise SystemExit(
            f"Unsupported geometry type: {gtype}. Expected Polygon or MultiPolygon"
        )


def to_xy(lon, lat, cent_lon, cent_lat):
    radius = 6371000.0
    x = math.radians(lon - cent_lon) * radius * math.cos(math.radians(cent_lat))
    y = math.radians(lat - cent_lat) * radius
    return x, y


def ring_area(ring: Iterable[List[float]], cent_lon: float, cent_lat: float) -> float:
    pts = [(float(p[0]), float(p[1])) for p in ring if len(p) >= 2]
    if len(pts) < 3:
        return 0.0
    if pts[0] != pts[-1]:
        pts.append(pts[0])

    total = 0.0
    for i in range(len(pts) - 1):
        x1, y1 = to_xy(pts[i][0], pts[i][1], cent_lon, cent_lat)
        x2, y2 = to_xy(pts[i + 1][0], pts[i + 1][1], cent_lon, cent_lat)
        total += x1 * y2 - x2 * y1
    return abs(total) / 2.0


def extract_geometry(doc):
    doc_type = doc.get("type")
    if doc_type in {"Polygon", "MultiPolygon"}:
        return doc
    if doc_type == "Feature":
        return doc.get("geometry")
    if doc_type == "FeatureCollection":
        features = doc.get("features", [])
        if not features:
            raise SystemExit("Polygon input has no features")
        return features[0].get("geometry")
    raise SystemExit(f"Unsupported GeoJSON type: {doc_type}")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: geojson_polygon_info.py /path/to/area.geojson")

    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        doc = json.load(handle)

    geom = extract_geometry(doc)
    if not geom:
        raise SystemExit("Could not extract geometry from polygon input")

    all_points: List[Tuple[float, float]] = []
    for ring in iter_rings(geom):
        for point in ring:
            if len(point) < 2:
                continue
            all_points.append((float(point[0]), float(point[1])))

    if not all_points:
        raise SystemExit("Geometry has no coordinates")

    min_lon = min(p[0] for p in all_points)
    max_lon = max(p[0] for p in all_points)
    min_lat = min(p[1] for p in all_points)
    max_lat = max(p[1] for p in all_points)

    cent_lon = (min_lon + max_lon) / 2.0
    cent_lat = (min_lat + max_lat) / 2.0

    area_m2 = 0.0
    if geom["type"] == "Polygon":
        rings = geom["coordinates"]
        if rings:
            area_m2 += ring_area(rings[0], cent_lon, cent_lat)
            for hole in rings[1:]:
                area_m2 -= ring_area(hole, cent_lon, cent_lat)
    elif geom["type"] == "MultiPolygon":
        for polygon in geom["coordinates"]:
            if not polygon:
                continue
            area_m2 += ring_area(polygon[0], cent_lon, cent_lat)
            for hole in polygon[1:]:
                area_m2 -= ring_area(hole, cent_lon, cent_lat)

    area_m2 = max(area_m2, 0.0)
    area_km2 = area_m2 / 1_000_000.0

    print(f"{min_lon},{min_lat},{max_lon},{max_lat}")
    print(f"{area_km2:.6f}")


if __name__ == "__main__":
    main()
