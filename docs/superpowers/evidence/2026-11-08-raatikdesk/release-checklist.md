# RaatikDesk release checklist — 2026-11-08

**Release: not accepted. Not shipped.** These documents do not authorize publication.

Commit inspected: `4c54a322cd99056fe954e8395d4091d861f9d76d` on `feat/raatikdesk-core-20261108`. No artifact was built, so there is no artifact SHA-256 and no runtime version to record.

Publication inputs named by EX-C06 were absent: production version, an approved source commit/artifact pair, a publisher credential, and deploy permission. Publication was not run.

## Gates

| Gate | State | Note |
|---|---|---|
| Two-device DPI matrix 100/125/150/200 | blocked | Only this workstation. No second Windows device. Visual rows and F01 stay blocked. |
| Native screenshots | not-run | None captured. No customer image. |
| Incoming/outgoing-only, connection types, reconnect, crash | not-run | F17, F20, F02–F06, F18 stay not-run. History harness passed separately and does not close them. |
| Catalog, uploader, download, install, portable update | deferred | UP-1, UP-2, UP-3, UP-4. F07–F16 and F19. Deferred is not passed. |
| Preserved ID, server, config, history, note after install | deferred | F16. No update was downloaded or installed. |
| UAC denial and rollback | deferred | F10, F12. |
| Icon source checker | passed | `raatik/test_verify_windows_icons.py`, 6 tests. Not native acceptance. |
| UAC manifest source checker (`asInvoker`) | passed | `raatik/test_verify_manifest_uac.py`, 10 tests. Not native acceptance. |
| Example fixture checker | passed | Sample matrix remains `not-run`. |
| Flutter 3.22.3 raatik widget files | failed | 440 passed, 1 failed (`Icons.settings` source assertion). Not native acceptance. |
| Flutter 3.24.5 same files | blocked | Would require rewriting the 3.22.3 package config. Lock and package config unchanged. |
| `cargo +1.75.0 test --offline --features flutter --lib raatik` | blocked | `scrap` build: `VCPKG_ROOT` unset. Not retried. |
| History harness | passed | 42 tests. Not a substitute for the crate test or for native rows. |
| Release-version checker | blocked | `raatik/test_verify_release_version.py` is not in the tree. |
| `raatik-check` branch filter | done | `feat/raatikdesk-core-20261108` added to push and pull_request filters. Pins, secrets, and jobs unchanged. Workflow was not dispatched. |
| `raatik-windows` / installer | not run | Not dispatched. No installer. |
| Issue #800 | open | Not closed. |
| `libs/hbb_common` | unchanged | `4700ebe84bb86e045888b7e12e09c68365236352` |

## Handoff

Native visual acceptance is still open. Do not mark `raatik/design/SCREENS.md` or the prototype README implemented from this record. Do not publish, push, or close GitHub issues from this checklist.
