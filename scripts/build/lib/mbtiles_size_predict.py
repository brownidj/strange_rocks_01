#!/usr/bin/env python3
import math
import sqlite3
import sys


def lon_to_xtile(lon: float, zoom: int) -> int:
    n = 2**zoom
    x = int((lon + 180.0) / 360.0 * n)
    return max(0, min(n - 1, x))


def lat_to_ytile(lat: float, zoom: int) -> int:
    n = 2**zoom
    clamped = max(-85.05112878, min(85.05112878, lat))
    rad = math.radians(clamped)
    y = int((1.0 - math.log(math.tan(rad) + (1 / math.cos(rad))) / math.pi) / 2.0 * n)
    return max(0, min(n - 1, y))


def main():
    if len(sys.argv) != 5:
        raise SystemExit(
            "Usage: mbtiles_size_predict.py minLon,minLat,maxLon,maxLat minZoom maxZoom source.mbtiles"
        )

    bbox = sys.argv[1]
    min_zoom = int(sys.argv[2])
    max_zoom = int(sys.argv[3])
    source = sys.argv[4]

    min_lon, min_lat, max_lon, max_lat = map(float, bbox.split(","))

    bbox_tiles = 0
    for zoom in range(min_zoom, max_zoom + 1):
        x_min = lon_to_xtile(min_lon, zoom)
        x_max = lon_to_xtile(max_lon, zoom)
        y_min = lat_to_ytile(max_lat, zoom)
        y_max = lat_to_ytile(min_lat, zoom)
        bbox_tiles += (abs(x_max - x_min) + 1) * (abs(y_max - y_min) + 1)

    conn = sqlite3.connect(source)
    cur = conn.cursor()
    avg_bytes = cur.execute("SELECT AVG(LENGTH(tile_data)) FROM tiles").fetchone()[0]
    conn.close()

    avg_tile_bytes = int(avg_bytes or 1500)
    predicted_size = bbox_tiles * avg_tile_bytes + 5 * 1024 * 1024

    print(str(bbox_tiles))
    print(str(avg_tile_bytes))
    print(str(predicted_size))


if __name__ == "__main__":
    main()
