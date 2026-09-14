#!/usr/bin/env python3
"""Fail if raatikdesk.exe is marked requireAdministrator.

The installed Windows service runs --server as LocalSystem and starts the
connection manager with run_as_user(["--cm"]), which ends in
CreateProcessAsUserW using explorer.exe's filtered, medium-integrity token
(src/platform/windows.cc, LaunchProcessWin). CreateProcessAsUser never
elevates, so an image requesting administrator fails with
ERROR_ELEVATION_REQUIRED (740). start_ipc then retries ten times one second
apart, gives up, and sends Data::CmErr, which closes the incoming session
after ~10s -- and the accept prompt, which only exists inside the --cm
process, never appears at all.

Upstream RustDesk ships asInvoker and elevates on demand via
elevate()/run_uac(). RaatikDesk must do the same. The installer produced by
libs/portable (res/manifest.xml) is a separate binary and is allowed to keep
requireAdministrator -- it is started by the user through the shell, where UAC
can prompt.
"""
import argparse
import re
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

# The manifest is embedded as plain UTF-8 XML in the RT_MANIFEST resource.
LEVEL_PATTERN = re.compile(rb"requestedExecutionLevel[^>]*?level\s*=\s*[\"']([^\"']+)[\"']")

# Sources that must not (re)introduce elevation for the Flutter runner.
SOURCE_FILES = (
    "flutter/windows/runner/CMakeLists.txt",
    "flutter/windows/runner/runner.exe.manifest",
)
SOURCE_PATTERN = re.compile(r"requireAdministrator")


def check_sources(root: Path) -> list[str]:
    """requireAdministrator must appear in neither runner source file."""
    errors = []
    for relative in SOURCE_FILES:
        path = root / relative
        if not path.is_file():
            errors.append(f"missing runner source: {relative}")
            continue
        text = path.read_text(encoding="utf-8")
        if relative.endswith(".manifest"):
            # mt.exe reports a malformed manifest only as "LNK1327: failure during
            # running mt.exe", 30 minutes into the build, with no parse detail. Catch
            # it here instead. A double hyphen inside an XML comment is the easy way
            # to trip this while writing a note about the cm command-line flag.
            try:
                ElementTree.fromstring(text)
            except ElementTree.ParseError as exc:
                errors.append(f"{relative} is not well-formed XML: {exc}")
        # Strip comments so the explanatory note in CMakeLists.txt does not trip the gate.
        stripped = "\n".join(
            line for line in text.splitlines() if not line.lstrip().startswith(("#", "<!--"))
        )
        if SOURCE_PATTERN.search(stripped):
            errors.append(f"requireAdministrator must not be set in {relative}")
    return errors


def check_binary(exe: Path) -> list[str]:
    """The built exe's embedded manifest must request asInvoker."""
    if not exe.is_file():
        return [f"binary not found: {exe}"]
    levels = {m.group(1).decode("ascii", "replace").lower() for m in LEVEL_PATTERN.finditer(exe.read_bytes())}
    if not levels:
        return [f"no requestedExecutionLevel found in {exe.name}"]
    bad = sorted(level for level in levels if level != "asinvoker")
    if bad:
        return [f"{exe.name} requests execution level {', '.join(bad)}; expected asInvoker"]
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--exe",
        type=Path,
        help="Built raatikdesk.exe to inspect (e.g. "
        "flutter/build/windows/x64/runner/Release/raatikdesk.exe)",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    errors = check_sources(root)
    if args.exe is not None:
        errors.extend(check_binary(args.exe))

    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1

    print("OK: raatikdesk.exe runs asInvoker (connection manager can start)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
