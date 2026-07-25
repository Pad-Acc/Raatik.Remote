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
| Build environment | **GitHub Actions only** — no local toolchain (§10) |
| Repo visibility | Public — free Actions minutes, satisfies AGPL source offer |
| Languages | Farsi (default) and English only; all others removed |
| RTL | Not implemented — Farsi text in the existing LTR layout |
| Server config | Compiled in as defaults, Network settings pane left visible and editable |
| Artifact | Unsigned self-extracting installer `.exe` |
| Official website | `raatik.com` (all brand links; docs links flattened to root — §8.3) |
| Fork strategy | Hybrid (see §4) |
| Fork remote | `https://github.com/Pad-Acc/Raatik.Remote.git` |
| `hbb_common` | Forked to `github.com/Pad-Acc/hbb_common`, `.gitmodules` repointed (§4.1) |
| Baseline | The `1.4.9` tag, not `master` |

## 3. Starting state (verified 2026-07-25)

- Source tree at `D:\Projects\RAATIK\RaatikRemote\rustdesk`, RustDesk **1.4.9**.
- `.git` present; on `master`, **29 commits ahead** of the `1.4.9` tag; working tree clean.
- `origin` → `https://github.com/rustdesk/rustdesk.git`.
- **`libs/hbb_common` is a submodule** whose pin differs per branch: `master` pins
  `559176122bdd5c8afa4e8fd5b706c3d901fb0c15`, while the **`1.4.9` tag — our baseline —
  pins `7e1c392c62d39c364127307cd408421dd5f8cfb0`** (`driver-298-g7e1c392`). It was
  initially unpopulated; it has since been fetched successfully, confirming
  `github.com/rustdesk/hbb_common` is reachable from this machine. Nothing compiles
  without it.
- **No build toolchain installed:** no Rust, no Flutter, no vcpkg, no LLVM.
- **No Visual Studio 2022.** `C:\Program Files\Microsoft Visual Studio\2022\` exists but is
  **empty**. What is installed is **Visual Studio 18 BuildTools** (Insiders/preview) at
  `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools`; `vswhere` confirms the
  C++ x86/x64 toolset is present, alongside Windows SDK `10.0.26100.0`.
- Python is the **Microsoft Store stub** at
  `C:\Users\Milad\AppData\Local\Microsoft\WindowsApps\python.exe` (reports 3.14.4).
  `build.py` shells out to `python3` and `pip3`; the Store build has restricted filesystem
  access and is an unreliable host for it.
- Disk: **C: has 41 GB free**, D: has 409 GB. The user requires that nothing new be
  installed on C:.

Together these are why the build is performed **exclusively in CI** (§10): vcpkg is pinned
to an early-2025 commit that predates VS 18 and must compile ffmpeg, aom, libvpx, libyuv,
opus and mfx-dispatch from source against it, which is an avoidable class of failure.
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

### 4.1 The `hbb_common` submodule must be forked too

Every high-leverage branding symbol — `APP_NAME`, `ORG`, `RENDEZVOUS_SERVERS`,
`RS_PUB_KEY`, `HELPER_URL` — lives in `libs/hbb_common`, which is a **separate git
repository** (`github.com/rustdesk/hbb_common`), not part of the main tree.

Changes there cannot be committed to `Raatik.Remote`: a submodule records only a pointer
to a commit in *its own* repository. Left unaddressed, CI would clone upstream
`hbb_common` and silently produce a binary with RustDesk's name, RustDesk's rendezvous
server and RustDesk's public key — while every local edit appeared to work.

Therefore `hbb_common` is forked to **`github.com/Pad-Acc/hbb_common`**, `.gitmodules` is
repointed at that fork, and the branding commits land there. The submodule pointer in
`Raatik.Remote` is then updated to the fork's commit.

Both repositories keep `origin` on their respective upstreams, so each remains
independently mergeable when RustDesk releases a new version. The cost is a second
repository to push and keep in sync — accepted as the price of a CI build that is
correct by construction rather than by remembering a patch step.

### 4.2 Implementation ordering — build vanilla first

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
  rewrites `RustDesk` → `RaatikDesk` inside translated strings at lookup time. This is why
  the language files need almost no hand-editing for the brand name.

**The substitution has two deliberate exclusions** ([lang.rs:227-228](../../../src/lang.rs))
which must be handled explicitly, or "RustDesk" reaches the user interface:

| Key | English value | Treatment |
|---|---|---|
| `powered_by_me` | `Powered by RustDesk` | Becomes **`Powered by RaatikDesk`**. Rendered at [flutter/lib/common.dart:3752](../../../flutter/lib/common.dart). Also hardcoded untranslated in [fa.rs:583](../../../src/lang/fa.rs), which must be updated too. |
| `upgrade_rustdesk_server_pro_*` | `Please upgrade RustDesk Server Pro to version {} or newer!` | Rewritten for string-table cleanliness. Unreachable for RAATIK — thrown only via RustDesk Server Pro at [group_model.dart:189](../../../flutter/lib/models/group_model.dart). |

Upstream exempts `powered_by_me` so that rebranded clients continue to credit RustDesk.
Changing it is permitted: RustDesk ships **plain AGPL-3.0** with no added §7(b) attribution
term, and no UI attribution string is legally required.

**Non-negotiable regardless:** the `LICENCE` file, all existing copyright headers, and the
offer of corresponding source (§3) are preserved. Rebranding removes RustDesk's *trademark*,
not its copyright notices.
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

All live in `libs/hbb_common/src/config.rs` (verified after fetching the submodule):

| Symbol | Line | Current value | Becomes |
|---|---|---|---|
| `RENDEZVOUS_SERVERS` | 120 | `&["rs-ny.rustdesk.com"]` | `&["remote.raatik.ir"]` |
| `RS_PUB_KEY` | 121 | `"OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw="` | `"Hl+uz02ouYRm03N9u9z9blRdHY0B9NYDPvqp7kYfcRs="` |
| `APP_NAME` | 72 | `RwLock::new("RustDesk")` | `RwLock::new("RaatikDesk")` |
| `ORG` | 57 | `RwLock::new("com.carriez")` | `RwLock::new("ir.raatik")` |

`RENDEZVOUS_SERVERS` is **already a single-element slice** upstream, so the `[0]` index and
`[1..]` empty-slice behaviour at [src/client.rs:299-300](../../../src/client.rs) are
unchanged by this edit. `RS_PUB_KEY` is consumed at
[src/client.rs:767,1806](../../../src/client.rs) and
[src/common.rs:1821](../../../src/common.rs).

`PROD_RENDEZVOUS_SERVER` (`config.rs:70`) is **not** an injection point. It is declared
`RwLock::new("")` and has **no writer anywhere** in either repository — only reads, at
`config.rs:919,945` and [src/common.rs:1040](../../../src/common.rs). The early-return
branch in `get_rendezvous_server()` is therefore dead code and is left untouched.

`build.rs` performs no environment-variable injection, so editing these constants is the
only mechanism available.

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

### 8.1 Deliberate exception: internal crate names are not renamed

The Cargo package name `rustdesk` and library name `librustdesk` are **kept unchanged**.

Renaming them ripples into the Flutter CMake configuration, the `flutter_rust_bridge`
glue, and `build.py`'s hardcoded output paths, for zero customer-visible benefit — no
one installing the product can observe a crate name. The *shipped artifact* is renamed;
the build internals are not. This preserves the white-label guarantee everywhere it is
actually observable while avoiding a large class of build breakage.

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

### 8.3 Outbound URLs and web references

The official website is **`raatik.com`** — deliberately distinct from the server domain
`remote.raatik.ir`.

A blanket find-and-replace of `rustdesk.com` is **incorrect and must not be performed**.
The occurrences fall into three categories with different treatments.

#### Rewritten to `raatik.com` (customer-visible brand links)

| Original | Becomes |
|---|---|
| `https://rustdesk.com`, `https://rustdesk.com/`, `http://www.rustdesk.com`, `https://www.rustdesk.com/` | `https://raatik.com` |
| `https://rustdesk.com/download`, `https://rustdesk.com/pricing` | `https://raatik.com` |
| `https://rustdesk.com/privacy.html`, `http://rustdesk.com/privacy` | `https://raatik.com/privacy` |
| the 8 `doc_*` deep links and `rustdesk.com/blog/id-relay-set/` | `https://raatik.com` |
| `hbb_common` `LINK_DOCS_HOME` (`config.rs:100`), `LINK_DOCS_X11_REQUIRED` (`:101`), `LINK_HEADLESS_LINUX_SUPPORT` (`:103`, a `github.com/rustdesk` wiki link) | `https://raatik.com` |

The `HELPER_URL` HashMap (`hbb_common/src/config.rs:106-109`) has **keys** containing the
literal string `rustdesk` (`"rustdesk docs home"`, etc.). These are internal lookup
identifiers passed from `src/`, never rendered, so they are left unchanged per the
functional-logic rule below; only the URL *values* they map to are rewritten. All three
are Linux-specific and unreachable in a Windows build, but are rewritten anyway so no
`rustdesk.com` string survives outside the §12 allowlist.

Documentation links are flattened to the site root rather than mirrored as
`raatik.com/docs/en/...`. Fabricating deep paths would produce guaranteed 404s until
RAATIK writes and hosts an equivalent documentation tree, and a dead link is worse than
a landing page. Most of these links are macOS/Linux-specific and unreachable in a
Windows-only build; the whitelist link is the one that can surface.

**RAATIK must host `raatik.com/privacy`.** A reachable privacy policy linked from the
About dialog is a reasonable legal expectation for distributed software, and it is the
one rewritten path that is not the site root.

#### Left unchanged (functional logic, never rendered to users)

- **`is_public()`** ([src/common.rs:1088](../../../src/common.rs)) and its unit tests
  ([src/common.rs:2768-2808](../../../src/common.rs)). Despite its name, this predicate
  means *"is this URL RustDesk Ltd's own hosted infrastructure?"* It gates self-hosted-only
  behaviour: audit posting ([common.rs:1120](../../../src/common.rs)), heartbeat
  ([sync.rs:281](../../../src/hbbs_http/sync.rs)), sysinfo hashing
  ([sync.rs:181](../../../src/hbbs_http/sync.rs)), UDP/IPv6 punch defaults
  ([common.rs:1110](../../../src/common.rs)), and raw-TCP API proxying
  ([common.rs:1144](../../../src/common.rs)).

  Rewriting it to `raatik.com` would create a latent footgun: the moment RAATIK hosts an
  API under `raatik.com`, audit and heartbeat would silently disable themselves. The test
  fixtures `rustdesk.com/path` and `rustdesk.computer.com` assert the lookalike-domain
  defense and must survive verbatim. None of these strings reach the UI.

- **`https://api.rustdesk.com/version/latest`** — unreachable, see below.

- **`https://admin.rustdesk.com`** ([src/common.rs:1083](../../../src/common.rs)) — a
  fallback returned only when no rendezvous server is configured. Unreachable because
  RAATIK's server is compiled in (§6). Verified unreachable rather than edited, to avoid
  altering the non-empty-string contract its callers rely on.

#### Automatic consequence: the update check disables itself

`check_software_update()` ([src/common.rs:943](../../../src/common.rs)) returns early when
`is_custom_client()` is true — which the `APP_NAME` change makes true (§5.3). RaatikDesk
therefore **never contacts `api.rustdesk.com`**. This is accepted deliberately: no
phone-home to RustDesk and no third-party telemetry about RAATIK's customers.

The trade-off is that **the product has no in-app update notification**; new versions are
distributed to customers manually. Repointing the version endpoint at RAATIK-hosted
infrastructure is out of scope for this iteration (§11).

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

## 10. Build environment — GitHub Actions only

**All compilation happens in CI. No toolchain is installed on the local machine.**

This supersedes an earlier decision to build both locally and in CI. The local machine has
no Rust, Flutter, LLVM or vcpkg, and — decisively — no VS 2022, only VS 18 Insiders (§3).
The pinned vcpkg commit predates VS 18 entirely and must build ffmpeg, aom, libvpx, libyuv,
opus and mfx-dispatch from source; `windows-2022` runners provide exactly the VS 2022
toolchain that pin was tested against. Building only in CI also avoids multi-GB downloads
over the local connection and makes the C:/D: installation constraint moot.

The local machine is used to **edit** source and to **install and test** the finished
artifact — running the built installer requires no toolchain.

### 10.1 Accepted cost: no local `cargo check`

Without a local toolchain there is no fast compile feedback; a stale `mod` line in
`lang.rs` or a mismatched brace costs a CI round-trip. This is mitigated by a **separate
lightweight check workflow** running `cargo check` only, which with warm `rust-cache` and
vcpkg binary caching completes in minutes rather than the ~40-60 minutes of a full build.

That workflow still requires vcpkg, because [build.rs:62](../../../build.rs) calls
`std::env::var("VCPKG_ROOT").unwrap()` and panics when it is unset — `cargo check` cannot
be run standalone even for pure string edits.

### 10.2 Release build workflow

A `raatik-windows.yml` derived from the `build-for-windows-flutter` job at
[.github/workflows/flutter-build.yml:80](../../../.github/workflows/flutter-build.yml),
reduced to the `x86_64-pc-windows-msvc` target with the `x64-windows-static` triplet.
All non-Windows jobs and the `windows-11-arm` matrix entry are removed. The workflow
uploads the installer as a build artifact.

Values pinned by the upstream workflow and preserved verbatim:

| Setting | Value |
|---|---|
| Runner | `windows-2022` |
| Rust | `1.75` (`SCITER_RUST_VERSION`), target `x86_64-pc-windows-msvc`, component `rustfmt` |
| Flutter | `3.24.5`, plus the custom RustDesk engine `windows-x64-release.zip` and the `flutter_3.24.4_dropdown_menu_enableFilter.diff` patch |
| LLVM | `15.0.6` |
| vcpkg | commit `120deac3062162151622ca4860575a33844ba10b`, triplet `x64-windows-static`, overlay ports `./res/vcpkg` |
| Build command | `python3 .\build.py --portable --flutter --hwcodec --vram` |

The upstream job passes `--skip-portable-pack` and packs the self-extracting installer in a
later step. Because RAATIK ships unsigned (§9), `--skip-portable-pack` is **dropped** so
`build_flutter_windows()` ([build.py:440](../../../build.py)) produces the installer
directly, and the upstream signing step is omitted.

The repository is **public**, which makes Actions minutes free and simultaneously satisfies
the AGPL source-offer obligation (§3).

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
- A RAATIK-hosted software-update endpoint, and any in-app update notification (§8.3).
- Authoring or hosting a documentation tree at `raatik.com/docs` (§8.3).
- A local build environment: installing Rust, Flutter, LLVM, vcpkg or Visual Studio 2022
  on this machine (§10). No compilation is performed locally.

## 12. Verification

No step below is treated as optional, and none of it is inferred from a successful
compile alone.

1. **Submodule** — `libs/hbb_common` populated at the fork's commit, with `.gitmodules`
   pointing at `Pad-Acc/hbb_common` (§4.1). Verified by confirming a fresh clone of
   `Raatik.Remote` yields branded values in `config.rs` — this is the check that catches
   the failure mode where local edits work but CI silently builds vanilla RustDesk.
2. **Compile** — the `cargo check` workflow green, then the full release build workflow
   green. Both run in CI; nothing is compiled locally (§10).
3. **No-leak gate** — scan the built binary's strings and the packaged installer for
   user-visible `RustDesk` and `rustdesk.com`. The gate operates against an **explicit
   allowlist** of known-acceptable residue, so it is meaningful rather than a blanket pass:
   internal crate and library names (§8.1), the `is_public()` predicate and its test
   fixtures, the unreachable `admin.rustdesk.com` fallback, and the dead version endpoint
   (all §8.3). Any occurrence outside the allowlist fails the gate.
4. **URL audit** — confirm no reachable code path opens a `rustdesk.com` URL, and that
   `https://raatik.com/privacy` resolves before release.
5. **Guard audit** — each of the seven `is_custom_client()` call sites in §5.3 reviewed
   and its post-flip behaviour recorded.
6. **Runtime, on a real install.** The artifact under test is the installer **downloaded
   from the CI run**, installed on a Windows machine exactly as a customer would. Since
   nothing is built locally, there is no local binary to confuse it with — and no "CI
   parity" question, because CI is the only build.
   - Farsi is the language on first launch, with English selectable.
   - About/window title/tray/Start Menu all read RaatikDesk.
   - Config directory is `%APPDATA%\RaatikDesk`.
   - The client registers with `remote.raatik.ir` without manual configuration.
   - The Network settings pane is present and editable.
7. **End-to-end** — a successful remote-control session between two Windows machines
   through `remote.raatik.ir`, confirming connection, input and screen capture.

## 13. Open items carried into implementation

The `hbb_common` symbol locations, the `PROD_RENDEZVOUS_SERVER` question and the
`HELPER_URL` contents were all resolved by fetching the submodule; see §6 and §8.3.
What remains:

- The mechanism for defaulting the language to Farsi rather than the OS locale (§7).
- The exact location in the Flutter About dialog where the Farsi company name is
  surfaced (§8.2).

Both are answerable by reading code in the populated tree and neither affects the
design; they are resolved during implementation.
