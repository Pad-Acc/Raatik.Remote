# RaatikDesk — White-label Rebrand of RustDesk 1.4.9 (Windows Desktop)

**Date:** 2026-07-25
**Status:** Approved design
**Scope:** Windows desktop client only

## 1. Goal

Produce a true white-label remote desktop client, **RaatikDesk**, from the RustDesk
1.4.9 source tree, for distribution to RAATIK's customers. A customer must never
encounter the name "RustDesk" anywhere in the product they install or run.

The client ships preconfigured for RAATIK's existing self-hosted server
(`remote.raatik.ir`) and in Farsi by default, with English as the only alternative
language.

## 2. Confirmed decisions

| Decision | Choice |
|---|---|
| Rebrand depth | True white-label — no visible "RustDesk" anywhere |
| Build environments | Both local and GitHub Actions |
| Languages | Farsi (default) and English only; all others removed |
| RTL | Not implemented — Farsi text in the existing LTR layout |
| Server config | Compiled in as defaults, Network settings pane left visible and editable |
| Artifact | Unsigned self-extracting installer `.exe` |
| Fork strategy | Hybrid (see §4) |
| Fork remote | `https://github.com/Pad-Acc/Raatik.Remote.git` |
| Baseline | The `1.4.9` tag, not `master` |

## 3. Starting state (verified 2026-07-25)

- Source tree at `D:\Projects\RAATIK\RaatikRemote\rustdesk`, RustDesk **1.4.9**.
- `.git` present; on `master`, **29 commits ahead** of the `1.4.9` tag; working tree clean.
- `origin` → `https://github.com/rustdesk/rustdesk.git`.
- **`libs/hbb_common` is empty** — submodule pinned at `559176122bdd5c8afa4e8fd5b706c3d901fb0c15`,
  never initialized. Nothing compiles until it is fetched. Remote
  `github.com/rustdesk/hbb_common` is reachable from this machine.
- **No build toolchain installed:** no Rust, no Flutter, no vcpkg, no LLVM.
  MSVC 2022 and Python 3.14.4 are present.
- Rebranding surface: 659 occurrences of `rustdesk` across 147 code files,
  plus 52 files in `src/lang/`.
- Farsi translation `src/lang/fa.rs` is 764/764 keys with **1** empty value.
- License is **AGPL-3.0**. Distributing a modified client obliges RAATIK to offer
  customers the corresponding source. A public fork at the remote above satisfies this.

### 3.1 Existing server (authoritative)

| Field | Value |
|---|---|
| ID server | `remote.raatik.ir` (raw IP `193.176.243.102` also valid) |
| Relay server | intentionally empty — `hbbs` runs with `-r remote.raatik.ir` and hands the relay back to clients |
| API server | empty (RustDesk Pro only) |
| Public key | `Hl+uz02ouYRm03N9u9z9blRdHY0B9NYDPvqp7kYfcRs=` |

The matching private key lives only at `/opt/rustdesk/data/id_ed25519` on the server.

## 4. Fork strategy — hybrid

`origin` remains RustDesk upstream so future releases can be merged normally. A new
remote `raatik` points at the RAATIK fork. All work happens on a branch
`raatik/1.4.9` cut from the **`1.4.9` tag**.

Rationale for the tag over `master`: `master`'s 29 extra commits are unreleased and
untested, the tag matches the `1.4.9` version string used throughout the build and
packaging, and the submodule pin is known-consistent at that point.

Work is split by *kind*, not by file:

- **Mechanical bulk** — language-file deletion, resource swaps, repetitive string
  renames — performed by a small checked-in script under `raatik/`, landed as one
  reviewable commit and re-runnable against a future upstream version.
- **Semantic** — `APP_NAME` default, compiled-in server defaults, the
  `is_custom_client()` audit, `Runner.rc`, packaging — hand-written as individually
  reviewable commits.

This keeps the human-authored diff small enough to review while making the bulk
work reproducible, and leaves upstream upgrades as an ordinary `git merge`.

### 4.1 Implementation ordering — build vanilla first

The implementation proceeds in two phases, in this order:

1. **Get an unmodified RustDesk 1.4.9 building on Windows**, locally and in CI, with
   zero rebranding applied.
2. **Apply the rebrand** on top of that known-good baseline.

This ordering is non-negotiable. Given that no toolchain currently exists (§3), a build
failure encountered *after* rebranding is ambiguous — vcpkg, the Flutter SDK version, and
the rebrand itself are all plausible causes, and disentangling them is far more expensive
than establishing the baseline first. Phase 1 also produces the reference artifact that
the §12.3 no-leak gate is diffed against.

## 5. Branding architecture

### 5.1 Exploit the existing indirection

RustDesk already routes its product name through a single runtime global. Setting
its default is the highest-leverage change in this project.

`hbb_common::config::APP_NAME` is an `RwLock<String>` defaulting to `"RustDesk"`.
Changing that default to `"RaatikDesk"` cascades automatically to:

- `get_app_name()` ([src/common.rs:1003](../../../src/common.rs)) — the bulk of UI text.
- `get_uri_prefix()` ([src/common.rs:1013](../../../src/common.rs)) — becomes `raatikdesk://`.
- The runtime brand substitution at [src/lang.rs:225-243](../../../src/lang.rs), which
  rewrites `RustDesk` → `RaatikDesk` inside **every translated string at lookup time**.
  This is why the language files need no hand-editing for the brand name.
- The config/data directory, derived from `APP_NAME` — becomes `%APPDATA%\RaatikDesk`.

Upstream's own custom-client path writes `APP_NAME` from a **signed** Pro
configuration blob ([src/common.rs:2202-2206](../../../src/common.rs)), verified against
RustDesk's key. We do not use that path; we change the compiled-in default instead.

### 5.2 Literals that bypass the indirection

These hardcode `"RustDesk"` and must be fixed by hand:

| Location | What it is |
|---|---|
| [src/auth_2fa.rs:17](../../../src/auth_2fa.rs) | `ISSUER` — the name shown in authenticator apps |
| [src/ipc/auth.rs:1017,1021](../../../src/ipc/auth.rs) | Windows credential/prompt strings |
| [src/platform/windows.rs:1992](../../../src/platform/windows.rs) | `get_custom_client_staging_dir()` path segments |
| [src/plugin/mod.rs:142](../../../src/plugin/mod.rs) | plugin directory path segment |
| [src/platform/macos.rs:311](../../../src/platform/macos.rs) | already substitutes via `get_app_name()`; verify only |

`hbb_common::config::ORG` (used for the macOS bundle identifier via `get_full_name()`)
is set to RAATIK's reverse-DNS identifier for consistency, though it is inert on Windows.

### 5.3 Behavioural guards that flip

Two predicates are defined in terms of the literal `"RustDesk"` and change value
once `APP_NAME` changes. Both must be audited, not assumed harmless.

- `is_rustdesk()` ([src/common.rs:1008](../../../src/common.rs)) — becomes `false`.
  It has exactly **one** caller, [src/lang.rs:225](../../../src/lang.rs), the brand
  substitution itself. Flipping it is precisely the desired effect. No action needed.
- `is_custom_client()` ([src/common.rs:2283](../../../src/common.rs)) — becomes `true`.
  This has **real behavioural callers** that must each be reviewed:
  [src/common.rs:942](../../../src/common.rs), [src/ipc.rs:868](../../../src/ipc.rs)
  (`is_pro() || is_custom_client()`), [src/flutter_ffi.rs:2475,2861](../../../src/flutter_ffi.rs),
  and [src/platform/windows.rs:1483,2106,2239](../../../src/platform/windows.rs).

  Each site is inspected and the resulting behaviour confirmed desirable before the
  build is considered correct. Any site whose new behaviour is unwanted is patched
  explicitly rather than by reverting `APP_NAME`.

### 5.4 Accepted consequence: customers get new device IDs

Because the config directory is derived from `APP_NAME`, RaatikDesk reads and writes
`%APPDATA%\RaatikDesk` rather than `%APPDATA%\RustDesk`. It therefore generates a
**fresh device ID** on every machine and installs alongside any existing RustDesk.

Existing customers running the current `rustdesk-1.4.8-x86_64.exe` will **not** carry
their IDs over. This is inherent to a genuine white-label and is accepted. It requires
customer communication and a re-registration step at rollout; no automatic migration
is in scope.

## 6. Compiled-in server defaults

The following `hbb_common::config` symbols are consumed by `src/` and are the
injection points for RAATIK's server (names verified against their call sites):

- `RENDEZVOUS_SERVERS` — a slice, indexed `[0]` and sliced `[1..]` at
  [src/client.rs:299-300](../../../src/client.rs). Reduced to a single entry
  `remote.raatik.ir`. A one-element slice keeps `[0]` valid and makes `[1..]` empty,
  which is safe.
- `RS_PUB_KEY` — a `&str` const consumed at [src/client.rs:767,1806](../../../src/client.rs)
  and [src/common.rs:1821](../../../src/common.rs). Set to
  `Hl+uz02ouYRm03N9u9z9blRdHY0B9NYDPvqp7kYfcRs=`.
- `PROD_RENDEZVOUS_SERVER` — an `RwLock<String>` checked first by
  `get_rendezvous_server()` at [src/common.rs:1040](../../../src/common.rs). It is only
  ever *read* in `src/`; its writer lives inside `hbb_common`.

**Confirm-on-fetch:** `build.rs` performs no environment-variable injection, so the exact
definition sites and the writer of `PROD_RENDEZVOUS_SERVER` must be located by reading
`libs/hbb_common/src/config.rs` after the submodule is initialized. The design commits to
patching the compiled-in defaults; the precise lines are determined then.

The relay field is deliberately left empty, matching current server behaviour. The
Network settings pane stays visible and editable so support staff can talk a customer
through a change; no settings are locked or hidden.

The filename-encoded configuration mechanism at
[src/custom_server.rs:39](../../../src/custom_server.rs) — which parses `host=` and `key=`
out of the executable's own name, and notably accepts unsigned JSON before attempting
signature verification — remains available as a fallback for one-off deployments.

## 7. Language reduction

Keep exactly three files in `src/lang/`: `en.rs`, `fa.rs`, and `template.rs`. Delete the
other 49. `template.rs` is the master key list and is **never edited**, per the project's
own guidance in `AGENTS.md`.

Changes required:

- Remove the 49 corresponding `mod` declarations at the top of
  [src/lang.rs](../../../src/lang.rs).
- Reduce the `LANGS` table ([src/lang.rs:52](../../../src/lang.rs)) to
  `[("en", "English"), ("fa", "فارسی")]`.
- Reduce `supportedLocales` ([flutter/lib/common.dart:649](../../../flutter/lib/common.dart))
  to `Locale('en')` and `Locale('fa')`.
- Make Farsi the default language rather than following the host OS locale.
- Fill the single empty value in `fa.rs`.

Text direction is left as-is. Farsi strings render in RustDesk's existing LTR layout,
which is how upstream already behaves for Arabic, Hebrew and Farsi — there is no
app-level `Directionality` anywhere in `flutter/lib`, and adding one is explicitly out
of scope (§11).

## 8. Windows identity and resources

Icons are regenerated from `raatik-logo.png` (in the parent project folder) into:

- `res/icon.ico`, `res/32x32.png`, `res/64x64.png`, `res/128x128.png`,
  `res/128x128@2x.png`, `res/tray-icon.ico`, `res/logo.svg`
- `flutter/windows/runner/resources/app_icon.ico`

Executable metadata in [flutter/windows/runner/Runner.rc:92-98](../../../flutter/windows/runner/Runner.rc):

| Field | From | To |
|---|---|---|
| `CompanyName` | `Purslane Tech Pte. Ltd.` | `Rayan Etemad Tosee Yekta (RAATIK)` |
| `FileDescription` | `RustDesk Remote Desktop` | `RaatikDesk Remote Desktop` |
| `InternalName` | `rustdesk` | `raatikdesk` |
| `LegalCopyright` | `Copyright © 2026 Purslane Tech Pte. Ltd. All rights reserved.` | `Copyright © 2026 Rayan Etemad Tosee Yekta (RAATIK). All rights reserved.` |
| `OriginalFilename` | `rustdesk.exe` | `raatikdesk.exe` |
| `ProductName` | `RustDesk` | `RaatikDesk` |

`Cargo.toml`'s `description` and `authors` are updated to RAATIK's.
`hbb_common::config::ORG` is set to **`ir.raatik`**, matching the `raatik.ir` domain.

### 8.2 Company name: Latin in resources, Farsi in the UI

The company's legal name has two forms:

- Latin: **Rayan Etemad Tosee Yekta (RAATIK)**
- Farsi: **رایان اعتماد توسعه یکتا (راتیک)**

Only the Latin form goes into `Runner.rc`. The version resource declares
`BLOCK "040904e4"` with `VALUE "Translation", 0x409, 1252` — US English with **codepage
1252 (Windows Latin-1)**, which has no representation for Farsi characters. Emitting
Farsi there would require switching the block to a Unicode codepage (`04b0` / 1200) and
re-encoding the `.rc`, which risks `rc.exe` mangling the file for no functional gain:
the version resource is surfaced only in the executable's Properties dialog, not in the
product UI. The existing `©` in `LegalCopyright` is retained because it is representable
in cp1252.

The Farsi form is used where Flutter renders Unicode natively and customers actually
read it — the About dialog and any in-app company attribution. Both forms are therefore
present in the product; they are simply placed according to what each layer can encode.

### 8.1 Deliberate exception: internal crate names are not renamed

The Cargo package name `rustdesk` and library name `librustdesk` are **kept unchanged**.

Renaming them ripples into the Flutter CMake configuration, the `flutter_rust_bridge`
glue, and `build.py`'s hardcoded output paths, for zero customer-visible benefit — no
one installing the product can observe a crate name. The *shipped artifact* is renamed;
the build internals are not. This preserves the white-label guarantee everywhere it is
actually observable while avoiding a large class of build breakage.

## 9. Packaging

`build.py --flutter` produces a self-extracting installer via
[libs/portable/](../../../libs/portable), named `rustdesk-{version}-install.exe` at
[build.py:466](../../../build.py). The shipped artifact is
**`RaatikDesk-1.4.9-install.exe`**.

Installer-visible identity — install directory, Start Menu entry, Windows service name,
and the uninstall registry entry — follows `get_app_name()` in the Windows install logic
in [src/platform/windows.rs](../../../src/platform/windows.rs) and is verified rather than
assumed.

Signing is not performed. The `signtool` invocation at
[build.py:511](../../../build.py), which expects a `cert.pfx`, is left wired but inactive
so that dropping in a certificate later is a one-line change. Customers will see a
Windows SmartScreen "unknown publisher" warning; this is accepted.

## 10. Build environments

Both are set up. Local for iteration, CI for reproducible release artifacts.

### 10.1 Local

Required and currently absent: Rust ≥ 1.75 (MSVC toolchain), the Flutter SDK pinned to
the version used by CI, LLVM, and vcpkg. MSVC 2022 and Python are already present.

vcpkg supplies `libvpx`, `libyuv`, `opus` and `aom` per [vcpkg.json](../../../vcpkg.json),
using the static triplet definitions in [res/vcpkg-triplets/](../../../res/vcpkg-triplets)
with `VCPKG_ROOT` exported. This step is the most common point of failure and is
validated before any rebranding work is judged complete.

### 10.2 GitHub Actions

A `raatik-windows.yml` derived from the `build-for-windows-flutter` job at
[.github/workflows/flutter-build.yml:80](../../../.github/workflows/flutter-build.yml),
reduced to the `x86_64-pc-windows-msvc` target with the `x64-windows-static` triplet.
All non-Windows jobs and the `windows-11-arm` matrix entry are removed. The workflow
uploads the installer as a build artifact.

## 11. Out of scope

- RTL layout support (Farsi renders LTR).
- Code signing and certificate procurement.
- MSI packaging (`res/msi/` has its own product name, upgrade GUID and service
  definitions and would need separate rebranding).
- Android, iOS, macOS and Linux clients.
- Server-side rebranding of `hbbs`/`hbbr`.
- RustDesk Pro features: API server, web console, signed custom-client configuration.
- Migrating existing customers' device IDs (see §5.4).
- Locking or hiding any settings pane.

## 12. Verification

No step below is treated as optional, and none of it is inferred from a successful
compile alone.

1. **Submodule** — `libs/hbb_common` populated at the pinned commit.
2. **Compile** — `cargo check`, then a release build with the `flutter` feature.
3. **No-leak gate** — scan the built binary's strings and the packaged installer for
   user-visible `RustDesk`. Known-acceptable residue (internal crate/library names per
   §8.1) is enumerated explicitly so the gate is meaningful rather than a blanket pass.
4. **Guard audit** — each of the seven `is_custom_client()` call sites in §5.3 reviewed
   and its post-flip behaviour recorded.
5. **Runtime, on a real install:**
   - Farsi is the language on first launch, with English selectable.
   - About/window title/tray/Start Menu all read RaatikDesk.
   - Config directory is `%APPDATA%\RaatikDesk`.
   - The client registers with `remote.raatik.ir` without manual configuration.
   - The Network settings pane is present and editable.
6. **End-to-end** — a successful remote-control session between two Windows machines
   through `remote.raatik.ir`, confirming connection, input and screen capture.
7. **CI parity** — the GitHub Actions workflow produces an installer equivalent to the
   local build.

## 13. Open items carried into implementation

- Exact definition sites in `libs/hbb_common/src/config.rs` for `APP_NAME`,
  `RENDEZVOUS_SERVERS`, `RS_PUB_KEY` and the writer of `PROD_RENDEZVOUS_SERVER`
  (§6, confirm-on-fetch).
- The mechanism for defaulting the language to Farsi rather than the OS locale (§7).
- The exact location in the Flutter About dialog where the Farsi company name is
  surfaced (§8.2).
