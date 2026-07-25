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
)

# The portable packer's data.bin container uses the bare literal b"rustdesk" as a
# start/end sentinel, written by libs/portable/generate.py and validated by
# libs/portable/src/bin_reader.rs. It is never rendered, and changing it requires
# editing both sides in lockstep or the installer is corrupt. Because the sentinel
# has no surrounding context to match on, installer files are checked with a count
# threshold rather than a context window -- see check_installer() below.
SENTINEL_ALLOWANCE = 2

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
    """For the installer: tolerate exactly the container-format sentinels.

    The packed payload is deflate-compressed, so brand strings inside the bundled
    executable are not present as plaintext here. Only the two bare b"rustdesk"
    sentinels should remain. More than that means a genuine plaintext leak.
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
