# RaatikDesk native acceptance — 2026-11-08

Release: **not accepted**. Issue #800 stays open. A one-machine or widget result cannot close it.

Tested repo: `D:\Projects\RAATIK\RaatikRemote\rustdesk`  
Branch: `feat/raatikdesk-core-20261108`  
Commit: `4c54a322cd99056fe954e8395d4091d861f9d76d`  
Submodule `libs/hbb_common`: `4700ebe84bb86e045888b7e12e09c68365236352` (unchanged)

`acceptance.json` is the sample matrix with results filled in. `docs/superpowers/plans/2026-11-08-raatikdesk-examples/acceptance-cases.json` is still all `not-run`. No screenshots were taken. `screenshots/` has no files. No EXE, secret, customer image, or capability URL is in this directory.

There is no artifact SHA-256 and no installed runtime version. No installer was built.

## Matrix

52 rows (32 visual + 20 functional).

| Status | Count | Rows |
|---|---:|---|
| passed | 0 | none |
| failed | 0 | none |
| blocked | 33 | all 32 visual rows, plus F01 |
| deferred | 11 | F07 F08 F09 F10 F11 F12 F13 F14 F15 F16 F19 |
| not-run | 8 | F02 F03 F04 F05 F06 F17 F18 F20 |

Deferred is not passed.

Blocked rows share one reason: the two-device 100/125/150/200% DPI matrix was not run. Only this workstation was available. There is no second Windows device here. F01 is the remote-corner case of that matrix.

Deferred rows are the update, catalog, uploader, download, install, and portable-update cases. The operator deferred UP-1, UP-2, UP-3, and UP-4. Those products were not branched, tested, downloaded, or installed.

Not-run rows were not executed on a native session. The widget suite, the history harness, and the Python checkers do not change them to passed.

## Commands

Host for every command below: one Windows x86_64 workstation. These results are automated or environment evidence. They are not native acceptance.

| Command | Result | Log |
|---|---|---|
| Flutter 3.22.3 `test --no-pub` on 24 `flutter/test/raatik_*.dart` files, from `flutter/` | **failed** (exit 1): 440 passed, 1 failed | `logs/flutter-3.22.3-raatik-tests.log` |
| Same files, Flutter 3.24.5 `test --no-pub` | **blocked** | `logs/flutter-3.24.5-raatik-tests.log` |
| `cargo +1.75.0 test --offline --features flutter --lib raatik` from the repo root | **blocked** (exit 101) | `logs/cargo-1.75-flutter-lib-raatik.log` |
| History harness, `cargo +1.75.0 test --offline --lib raatik::history_tests -- --test-threads=1` with `RUSTFLAGS=--cfg raatik_history_harness` | **passed** (exit 0): 42 passed, 0 failed | `logs/cargo-1.75-history-harness.log` |
| `python docs/superpowers/plans/2026-11-08-raatikdesk-examples/verify_examples.py` | **passed** (exit 0) | `logs/docs_superpowers_plans_2026-11-08-raatikdesk-examples_verify_examples.py.log` |
| `python raatik/test_verify_release_version.py` | **blocked** (exit 2): file not in the tree | `logs/raatik_test_verify_release_version.py.log` |
| `python raatik/test_verify_windows_icons.py` | **passed** (exit 0): 6 tests | `logs/raatik_test_verify_windows_icons.py.log` |
| `python raatik/test_verify_manifest_uac.py` | **passed** (exit 0): 10 tests | `logs/raatik_test_verify_manifest_uac.py.log` |

`test/raatik_test_app.dart` was not passed to Flutter. It is a shared harness and has no test `main`.

### Flutter 3.22.3 failure

`desktop_tab_page Settings ActionIcon uses Icons.settings not IconFont.menu` expected `true` and got `false` (`flutter/test/raatik_settings_icon_test.dart`). The other 440 tests passed. Lockfile and package config were unchanged. This is a widget/source assertion. It does not fail or pass a native row.

### Flutter 3.24.5 blocked

The tool started (Dart 3.5.4) and did not rewrite `flutter/pubspec.lock` or `flutter/.dart_tool/package_config.json`. That package config still points `flutter` at `D:/Toolchains/Flutter/3.22.3/packages/flutter`. The 3.24.5 compiler then failed every load with `setRasterizerTracingThreshold` missing on `SceneBuilder` (`dart:ui`), 24 files, `+0 -24`. Pointing the package config at the 3.24.5 framework would rewrite the 3.22.3 package config, so the run is blocked and was not retried. It is not a product failure.

### Root crate blocked

`VCPKG_ROOT` and `LIBCLANG_PATH` were unset. The first toolchain error, from `libs/scrap/build.rs`, was:

```text
Couldn't find VCPKG_ROOT, also can't fallback to homebrew because it's only for macos aarch64.
```

Exit 101. vcpkg and libclang were not installed. The command was not retried. This is not a product assertion failure. The history harness does not replace this crate test.

### History harness

42 tests passed in 8.47s, including reconnect, two-process writers, and the six-transport forward case. That is separate evidence. F02, F03, F04, F05, F06, and F20 stay `not-run`.

### Python

`verify_examples.py` checks the sample fixtures only. It printed `PASS: 3 fixture files; 32 native visual cases; 20 functional cases; examples only.` Icon and UAC checkers passed. None of those results mark a native row passed. `raatik/test_verify_release_version.py` is not in the repo; the other `raatik/test_verify_*.py` files are the icon and manifest checkers, which were run separately.

## Still open

- Native visual acceptance for all eight surfaces at 100/125/150/200% DPI, including corners and clicks.
- Native functional cases F02, F03, F04, F05, F06, F17, F18, and F20.
- Every deferred update row.
- Screenshots, artifact hash, and runtime version.
- Root crate `--features flutter` tests, until `VCPKG_ROOT` is provided without installing it ad hoc in this task.
- A Flutter 3.24.5 run that does not rewrite the 3.22.3 package config.
- The settings-icon widget assertion above.
