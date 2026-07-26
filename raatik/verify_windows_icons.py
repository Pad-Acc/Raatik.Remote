#!/usr/bin/env python3
"""Verify Raatik Windows icons match canonical res/icon.* sources."""
import argparse
import hashlib
import sys
from pathlib import Path


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_icon_sources(root: Path) -> list[str]:
    groups = {
        "res/icon.ico": (
            "res/tray-icon.ico",
            "flutter/windows/runner/resources/app_icon.ico",
            "flutter/assets/icon.ico",
        ),
        "res/icon.png": ("flutter/assets/icon.png",),
    }
    errors = []
    for canonical, candidates in groups.items():
        source = root / canonical
        if not source.is_file():
            errors.append(f"missing canonical icon: {canonical}")
            continue
        expected = _sha256(source)
        for relative in candidates:
            candidate = root / relative
            if not candidate.is_file():
                errors.append(f"missing icon: {relative}")
            elif _sha256(candidate) != expected:
                errors.append(f"icon differs from {canonical}: {relative}")
    return errors


def check_release_icons(root: Path, release_dir: Path) -> list[str]:
    groups = {
        "res/icon.ico": ("data/flutter_assets/assets/icon.ico",),
        "res/icon.png": ("data/flutter_assets/assets/icon.png",),
    }
    errors = []
    for canonical, candidates in groups.items():
        source = root / canonical
        if not source.is_file():
            errors.append(f"missing canonical icon: {canonical}")
            continue
        expected = _sha256(source)
        for relative in candidates:
            candidate = release_dir / relative
            if not candidate.is_file():
                errors.append(f"missing release icon: {relative}")
            elif _sha256(candidate) != expected:
                errors.append(f"release icon differs from {canonical}: {relative}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--release-dir",
        type=Path,
        help="Built Release directory (e.g. flutter/build/windows/x64/runner/Release)",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    errors = check_icon_sources(root)
    if args.release_dir is not None:
        if not args.release_dir.is_dir():
            errors.append(f"release directory not found: {args.release_dir}")
        else:
            errors.extend(check_release_icons(root, args.release_dir))

    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1

    print("OK: Windows icons match canonical sources")
    return 0


if __name__ == "__main__":
    sys.exit(main())
