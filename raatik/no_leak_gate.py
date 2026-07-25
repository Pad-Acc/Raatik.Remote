#!/usr/bin/env python3
"""Fail if a user-visible RustDesk brand string survives in a built artifact.

Allowlisted residue is documented in the spec (sections 8.1 and 8.3):
internal crate/library names, the is_public() predicate and its test
fixtures, the unreachable admin.rustdesk.com fallback, and the dead
version endpoint.
"""
import re
import sys
from pathlib import Path

ALLOWLIST = (
    b"librustdesk",                   # section 8.1: Rust cdylib name, loaded by main.cpp
    b"rustdesk.com/",                 # section 8.3: is_public() predicate
    b"rustdesk.computer.com",         # section 8.3: lookalike-domain test fixture
    b"admin.rustdesk.com",            # section 8.3: unreachable fallback
    b"api.rustdesk.com",              # section 8.3: dead version endpoint
    b"RuntimeBroker_rustdesk.exe",    # third-party TempTopMostWindow helper binary
    b"RustDesk://FsJob",              # Task 7: internal printer job id (wire-format-adjacent)
    b"RustDeskPrivacyWindow",         # Task 7: privacy window class/name (third-party lookup)
    b"RustDeskIddDriver",             # Task 7: virtual display IDD device string
    b"DeleteRustDeskTestCertsW",      # Task 7: exported DLL symbol name
    b"rustdesk_idd",                  # Task 7: IDD impl selector string
    b"org.rustdesk.rustdesk",         # section 8.1: Flutter MethodChannel (Dart + C++ IPC)
    b"rustdesk_core_main",            # section 8.1: FFI export loaded from librustdesk.dll
    b"get_rustdesk_app_name",         # section 8.1: FFI export loaded from librustdesk.dll
)

# Installer-only residue (count threshold in check_installer). Four measured hits in CI
# run 30170937072; all packer-internal, never customer-visible:
#   1. data.bin start sentinel (generate.py:42) adjacent to first packed path entry
#   2. data.bin end sentinel (generate.py:57) adjacent to .\raatikdesk.exe path
#   3-4. bin_reader.rs identifier comparisons compiled into the packer exe
# Changing the sentinel requires editing generate.py and bin_reader.rs in lockstep.
SENTINEL_ALLOWANCE = 4

PATTERN = re.compile(rb"[Rr]ust[Dd]esk")


def unallowlisted(path: Path) -> list[bytes]:
    """Every brand match whose surrounding bytes contain no allowlisted string."""
    data = path.read_bytes()
    found = []
    for match in PATTERN.finditer(data):
        window = data[max(0, match.start() - 40): match.end() + 40]
        if not any(allowed in window for allowed in ALLOWLIST):
            found.append(window)
    return found


def check_strict(path: Path) -> bool:
    """For the runner exe: any unallowlisted occurrence is a failure."""
    found = unallowlisted(path)
    if found:
        print(f"FAIL: {len(found)} brand leak(s) in {path}", file=sys.stderr)
        for window in found[:20]:
            print(f"  ...{window!r}...", file=sys.stderr)
        return False
    print(f"OK: no brand leak in {path}")
    return True


def check_installer(path: Path) -> bool:
    """For the installer: tolerate packer-internal residue up to SENTINEL_ALLOWANCE.

    The packed payload is brotli-compressed, so brand strings inside bundled DLLs
    are not present as plaintext. Expected hits are the two data.bin sentinels plus
    the bin_reader.rs comparison literals embedded in the packer binary. More than
    SENTINEL_ALLOWANCE means a genuine plaintext leak.
    """
    found = unallowlisted(path)
    if len(found) > SENTINEL_ALLOWANCE:
        print(
            f"FAIL: {len(found)} brand occurrence(s) in {path}, "
            f"expected at most {SENTINEL_ALLOWANCE} container sentinels",
            file=sys.stderr,
        )
        for window in found[:20]:
            print(f"  ...{window!r}...", file=sys.stderr)
        return False
    print(f"OK: {len(found)} sentinel(s) only in {path}")
    return True


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: no_leak_gate.py <file> [<file>...]", file=sys.stderr)
        return 2
    ok = True
    for arg in sys.argv[1:]:
        path = Path(arg)
        if not path.is_file():
            print(f"FAIL: not a file: {path}", file=sys.stderr)
            ok = False
            continue
        if path.name.lower().endswith("install.exe"):
            ok &= check_installer(path)
        else:
            ok &= check_strict(path)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
