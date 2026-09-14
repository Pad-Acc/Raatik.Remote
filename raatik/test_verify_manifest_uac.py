#!/usr/bin/env python3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from verify_manifest_uac import check_binary, check_sources

ASINVOKER = b'<requestedExecutionLevel level="asInvoker" uiAccess="false" />'
REQUIRE_ADMIN = b'<requestedExecutionLevel level="requireAdministrator" uiAccess="false" />'

CMAKE_CLEAN = """add_executable(${BINARY_NAME} WIN32 "main.cpp")
add_dependencies(${BINARY_NAME} flutter_assemble)
"""
CMAKE_ELEVATED = """add_executable(${BINARY_NAME} WIN32 "main.cpp")
set_target_properties(${BINARY_NAME} PROPERTIES LINK_FLAGS
  "/MANIFESTUAC:\\"level='requireAdministrator' uiAccess='false'\\"")
"""
MANIFEST_CLEAN = "<assembly><compatibility/></assembly>\n"


class CheckSourcesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _write_sources(self, cmake: str, manifest: str = MANIFEST_CLEAN) -> None:
        runner = self.root / "flutter/windows/runner"
        runner.mkdir(parents=True, exist_ok=True)
        (runner / "CMakeLists.txt").write_text(cmake, encoding="utf-8")
        (runner / "runner.exe.manifest").write_text(manifest, encoding="utf-8")

    def test_clean_sources_pass(self) -> None:
        self._write_sources(CMAKE_CLEAN)
        self.assertEqual(check_sources(self.root), [])

    def test_manifestuac_link_flag_is_rejected(self) -> None:
        self._write_sources(CMAKE_ELEVATED)
        errors = check_sources(self.root)
        self.assertIn(
            "requireAdministrator must not be set in flutter/windows/runner/CMakeLists.txt",
            errors,
        )

    def test_trustinfo_in_manifest_is_rejected(self) -> None:
        self._write_sources(
            CMAKE_CLEAN,
            '<assembly><trustInfo><requestedExecutionLevel level="requireAdministrator"/>'
            "</trustInfo></assembly>\n",
        )
        errors = check_sources(self.root)
        self.assertIn(
            "requireAdministrator must not be set in "
            "flutter/windows/runner/runner.exe.manifest",
            errors,
        )

    def test_explanatory_comment_does_not_trip_the_gate(self) -> None:
        self._write_sources("# do NOT mark this requireAdministrator\n" + CMAKE_CLEAN)
        self.assertEqual(check_sources(self.root), [])

    def test_missing_source_reports_error(self) -> None:
        errors = check_sources(self.root)
        self.assertIn(
            "missing runner source: flutter/windows/runner/CMakeLists.txt", errors
        )


class CheckBinaryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _exe(self, payload: bytes) -> Path:
        path = self.root / "raatikdesk.exe"
        path.write_bytes(b"MZ\x00\x00" + payload + b"\x00padding")
        return path

    def test_asinvoker_passes(self) -> None:
        self.assertEqual(check_binary(self._exe(ASINVOKER)), [])

    def test_require_administrator_fails(self) -> None:
        errors = check_binary(self._exe(REQUIRE_ADMIN))
        self.assertEqual(len(errors), 1)
        self.assertIn("requireadministrator", errors[0].lower())

    def test_no_manifest_level_fails(self) -> None:
        errors = check_binary(self._exe(b"no manifest here"))
        self.assertIn("no requestedExecutionLevel found in raatikdesk.exe", errors)

    def test_missing_binary_reports_error(self) -> None:
        errors = check_binary(self.root / "absent.exe")
        self.assertEqual(len(errors), 1)
        self.assertIn("binary not found", errors[0])


if __name__ == "__main__":
    unittest.main()
