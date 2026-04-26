#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
from typing import Dict, List


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_manifest(pack_root: Path) -> Dict[str, object]:
    entries: List[Dict[str, object]] = []
    for file_path in sorted(pack_root.rglob("*")):
        if not file_path.is_file():
            continue
        relative = file_path.relative_to(pack_root).as_posix()
        entries.append(
            {
                "path": relative,
                "size_bytes": file_path.stat().st_size,
                "sha256": sha256_file(file_path),
            }
        )

    bundle_hash = hashlib.sha256(
        "\n".join(f"{e['path']}:{e['sha256']}" for e in entries).encode("utf-8")
    ).hexdigest()

    return {
        "manifest_version": 1,
        "file_count": len(entries),
        "bundle_sha256": bundle_hash,
        "files": entries,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Write artifact checksum manifest for a generated field-pack folder."
    )
    parser.add_argument("--pack-root", required=True, help="Path to generated pack root")
    parser.add_argument(
        "--output",
        default="artifact_manifest.json",
        help="Output manifest path (default: artifact_manifest.json in pack root)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    pack_root = Path(args.pack_root).resolve()
    if not pack_root.exists() or not pack_root.is_dir():
        raise SystemExit(f"Pack root not found or not a directory: {pack_root}")

    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = pack_root / output_path

    manifest = build_manifest(pack_root)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote artifact manifest: {output_path}")


if __name__ == "__main__":
    main()
