# Baseline — RaatikDesk delivery 2026-11-08

Recorded before product source edits.

- R HEAD: `fdf4b9e6623c92d52a5f75869d1c9a8d6ed13e3d`
- R branch: `feat/raatikdesk-core-20261108` (from `raatik/ui-numbers-rtl`)
- Submodule `libs/hbb_common`: `4700ebe84bb86e045888b7e12e09c68365236352`
- Preserved and not part of feature commits unless a later task names them: `AGENTS.md`, `raatik/design/SCREENS.md`, untracked plans, specs, and `raatik/design/prototypes/`
- Host `D:\flutter`: 3.44.8. Leave it unchanged. It is not the pinned SDK.
- Pinned Flutter 3.22.3 is installed at `D:\Toolchains\Flutter\3.22.3` (Dart 3.4.4). Windows precache completed.
- Pinned Flutter 3.24.5 is installed at `D:\Toolchains\Flutter\3.24.5` (Dart 3.5.4). Windows precache completed. Use it for the IN-1 release-SDK pass, not for day-to-day tests.
- Default Rust remains stable 1.97.1. `cargo +1.75.0` is available (`rustc 1.75.0`). The default toolchain was not switched.
- `cargo-expand` and `flutter_rust_bridge_codegen` were not on PATH at baseline.
- Existing widget-test baseline: not run yet, because the pinned Flutter SDK was absent.

## Flutter 3.22.3 transcript

No pre-edit Flutter log is in this package. The first captured Flutter 3.22.3 transcript is `logs/flutter-3.22.3-raatik-tests.log` (440 passed, 1 settings-icon failure). That transcript is the IN-1 acceptance run. It is not a pre-edit regression baseline.

## IN-1 acceptance run

Recorded 2026-11-09 against branch `feat/raatikdesk-core-20261108`. HEAD `4c54a322cd99056fe954e8395d4091d861f9d76d` was not amended. Submodule `libs/hbb_common` remained `4700ebe84bb86e045888b7e12e09c68365236352`.

Host: one Windows x86_64 workstation (session OS 10.0.26300). No second Windows device. `VCPKG_ROOT` and `LIBCLANG_PATH` were unset. `pub get` was not run. `flutter/pubspec.lock` and `flutter/.dart_tool/package_config.json` stayed at SHA-256 `5B1D1903F9B7E4D8EBAED2CC127EE16EEB60CB0B23CB490EE53825D174FBCBC3` and `1479FF18623C81B35310B29378837E01453FBEA217434DB6D13E376229E794BC`. vcpkg, libclang, `flutter_rust_bridge_codegen`, and cargo-expand were not installed. `raatik-windows` was not dispatched. No installer was built. Nothing was published. Issue #800 was not closed. UP-1, UP-2, UP-3, and UP-4 stayed deferred: no WebV3 or AutoFi branch, no catalog or uploader test, no download, and no install.

`package_config.json` still binds the Flutter package to `file:///D:/Toolchains/Flutter/3.22.3/packages/flutter`. That is why the 3.24.5 invocation could not exercise the 3.24.5 framework without rewriting the package config.

Command outcomes are in `acceptance.md`. Logs are under `logs/`. This run does not accept the release.
