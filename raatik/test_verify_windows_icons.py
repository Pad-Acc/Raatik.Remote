#!/usr/bin/env python3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from verify_windows_icons import check_icon_sources, check_release_icons


class CheckIconSourcesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _write(self, relative: str, content: bytes) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def test_missing_candidate_reports_error(self) -> None:
        ico = b"canonical-ico"
        png = b"canonical-png"
        self._write("res/icon.ico", ico)
        self._write("res/icon.png", png)
        self._write("res/tray-icon.ico", ico)
        self._write("flutter/windows/runner/resources/app_icon.ico", ico)

        errors = check_icon_sources(self.root)

        self.assertIn("missing icon: flutter/assets/icon.ico", errors)
        self.assertIn("missing icon: flutter/assets/icon.png", errors)

    def test_mismatched_candidate_reports_error(self) -> None:
        ico = b"canonical-ico"
        png = b"canonical-png"
        self._write("res/icon.ico", ico)
        self._write("res/icon.png", png)
        self._write("res/tray-icon.ico", b"stale-tray")
        self._write("flutter/windows/runner/resources/app_icon.ico", ico)
        self._write("flutter/assets/icon.ico", ico)
        self._write("flutter/assets/icon.png", png)

        errors = check_icon_sources(self.root)

        self.assertIn("icon differs from res/icon.ico: res/tray-icon.ico", errors)
        self.assertEqual(len(errors), 1)

    def test_matching_icons_pass(self) -> None:
        ico = b"canonical-ico"
        png = b"canonical-png"
        self._write("res/icon.ico", ico)
        self._write("res/icon.png", png)
        for relative in (
            "res/tray-icon.ico",
            "flutter/windows/runner/resources/app_icon.ico",
            "flutter/assets/icon.ico",
            "flutter/assets/icon.png",
        ):
            self._write(relative, ico if relative.endswith(".ico") else png)

        self.assertEqual(check_icon_sources(self.root), [])


class CheckReleaseIconsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.release = self.root / "Release"
        self.release.mkdir()

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _write(self, relative: str, content: bytes) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def test_missing_release_icon_reports_error(self) -> None:
        self._write("res/icon.ico", b"canonical-ico")
        self._write("res/icon.png", b"canonical-png")
        self._write(
            "Release/data/flutter_assets/assets/icon.ico",
            b"canonical-ico",
        )

        errors = check_release_icons(self.root, self.release)

        self.assertIn(
            "missing release icon: data/flutter_assets/assets/icon.png",
            errors,
        )

    def test_mismatched_release_icon_reports_error(self) -> None:
        self._write("res/icon.ico", b"canonical-ico")
        self._write("res/icon.png", b"canonical-png")
        self._write(
            "Release/data/flutter_assets/assets/icon.ico",
            b"stale-runtime-ico",
        )
        self._write(
            "Release/data/flutter_assets/assets/icon.png",
            b"canonical-png",
        )

        errors = check_release_icons(self.root, self.release)

        self.assertIn(
            "release icon differs from res/icon.ico: "
            "data/flutter_assets/assets/icon.ico",
            errors,
        )

    def test_matching_release_icons_pass(self) -> None:
        self._write("res/icon.ico", b"canonical-ico")
        self._write("res/icon.png", b"canonical-png")
        self._write(
            "Release/data/flutter_assets/assets/icon.ico",
            b"canonical-ico",
        )
        self._write(
            "Release/data/flutter_assets/assets/icon.png",
            b"canonical-png",
        )

        self.assertEqual(check_release_icons(self.root, self.release), [])


if __name__ == "__main__":
    unittest.main()
