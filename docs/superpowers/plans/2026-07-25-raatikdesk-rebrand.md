# RaatikDesk Rebrand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the RustDesk 1.4.9 source tree into a white-label Windows client called RaatikDesk, preconfigured for `remote.raatik.ir`, Farsi by default, built entirely in GitHub Actions.

**Architecture:** Two git forks (`Raatik.Remote` and `hbb_common`) tracking their upstreams. Branding flows from a single `APP_NAME` default in `hbb_common`, which cascades through `get_app_name()`, the URI scheme, the config directory, and the runtime brand substitution in `lang.rs`. Only literals that bypass that indirection are hand-edited. Compilation happens exclusively in CI.

**Tech Stack:** Rust 1.75 (MSVC), Flutter 3.24.5, vcpkg `120deac3`, GitHub Actions `windows-2022`, Python 3 (`build.py`).

**Spec:** [2026-07-25-raatikdesk-rebrand-design.md](../specs/2026-07-25-raatikdesk-rebrand-design.md). Section references below (§N) point into it.

## Global Constraints

These apply to every task. Values are copied verbatim from the spec.

- **Product name:** `RaatikDesk`. **URI scheme:** `raatikdesk://`. **Config dir:** `%APPDATA%\RaatikDesk`.
- **Company (Latin):** `Rayan Etemad Tosee Yekta (RAATIK)` — the only form permitted in `Runner.rc`, whose version block is codepage 1252 and cannot encode Farsi (§8.2).
- **Company (Farsi):** `رایان اعتماد توسعه یکتا (راتیک)` — Flutter UI only.
- **Copyright:** `Copyright © 2026 Rayan Etemad Tosee Yekta (RAATIK). All rights reserved.`
- **Website:** `https://raatik.com`. **Privacy:** `https://raatik.com/privacy`.
- **ID server:** `remote.raatik.ir`. **Public key:** `Hl+uz02ouYRm03N9u9z9blRdHY0B9NYDPvqp7kYfcRs=`. **Relay:** left empty (§3.1). **`config::ORG`:** `ir.raatik`.
- **Languages:** English and Farsi only; Farsi is the default. Layout stays LTR — **no RTL work** (§7, §11).
- **Never rename** the Cargo package `rustdesk` or the library `librustdesk` (§8.1). `main.cpp:25` does `LoadLibraryA("librustdesk.dll")`.
- **Never rewrite** `is_public()` or its test fixtures, including `rustdesk.computer.com` (§8.3). It means "is this RustDesk's own hosted infrastructure" and gates audit, heartbeat and punch defaults.
- **Never edit** `src/lang/template.rs` — it is the master key list (`AGENTS.md`).
- **Preserve** the `LICENCE` file, all copyright headers, and the AGPL source offer (§5.1).
- **No local compilation.** All builds run in CI (§10). Nothing is installed on this machine.
- **Settings stay editable** — do not hide or lock the Network pane (§11).
- Follow the repo's own `AGENTS.md`: smallest valid diff, no unrelated refactoring, no formatting-only changes, avoid `unwrap()` in production paths.

## File Structure

**Fork A — `github.com/Pad-Acc/hbb_common`** (submodule at `libs/hbb_common`)
- `src/config.rs` — `APP_NAME`, `ORG`, `RENDEZVOUS_SERVERS`, `RS_PUB_KEY`, `LINK_*` constants, and the existing `mod tests` at line 3279 where branding tests go.

**Fork B — `github.com/Pad-Acc/Raatik.Remote`** (this repo)
- `.gitmodules` — repointed at Fork A.
- `src/auth_2fa.rs`, `src/ipc/auth.rs`, `src/platform/windows.rs`, `src/plugin/mod.rs` — literals bypassing `get_app_name()`.
- `src/lang.rs` — `mod` list, `LANGS` table, substitution exclusions. Gains a new `mod tests`.
- `src/lang/` — reduced to `en.rs`, `fa.rs`, `template.rs`.
- `flutter/lib/common.dart` — `supportedLocales`, `powered_by_me` rendering.
- `flutter/windows/CMakeLists.txt` — `BINARY_NAME`, `project()`.
- `flutter/windows/runner/Runner.rc` — version resource.
- `res/` and `flutter/windows/runner/resources/` — icons.
- `build.py` — installer name and embedded-exe path.
- `.github/workflows/raatik-windows.yml` — release build (new).
- `.github/workflows/raatik-check.yml` — fast `cargo check` (new).
- `raatik/no_leak_gate.py` — brand-leak gate with allowlist (new).

---

### Task 1: Fork both repos and push the unmodified baseline

Establishes the two forks and proves the submodule wiring works before any code changes. Nothing is rebranded yet — this task's deliverable is a public repo whose fresh clone reproduces the vanilla 1.4.9 tree.

> **Executed 2026-07-25. Two corrections learned the hard way — read before re-running.**
>
> 1. **Both repos must be created with `gh repo fork`, never as empty repos.** The first
>    attempt created `Raatik.Remote` empty and pushed 11,239 commits / 76 MB from the local
>    machine. It died with `RPC failed; HTTP 408` after 20 MB, and `http.postBuffer=500MB` +
>    `http.lowSpeedLimit=0` did not help. `gh repo fork` copies server-side on GitHub's
>    infrastructure, after which the branch push is only the ~9 RAATIK commits (51 objects)
>    and completes instantly. The empty repo was renamed to `Raatik.Remote.placeholder` to
>    free the name; it can be deleted once the token has `delete_repo` scope.
> 2. **The fork's default branch must be set to `raatik/1.4.9`.** A fork inherits upstream's
>    `master`, and GitHub only allows `workflow_dispatch` on workflows present on the
>    **default** branch — so Task 2's manual trigger would fail with "workflow does not
>    exist". This supersedes the original "do not change the default branch" instruction,
>    which assumed a fresh empty repo.
>
> Verification was done via the GitHub API rather than a 75 MB clone, which is both cheaper
> and stricter — it confirms the exact refs CI resolves: `.gitmodules` → `Pad-Acc/hbb_common`,
> gitlink `7e1c392c`, that commit present in the fork, and `APP_NAME` still `"RustDesk"`.

**Files:**
- Modify: `.gitmodules`

**Interfaces:**
- Produces: remotes `raatik` on both repos; branch `raatik/1.4.9` on both; `.gitmodules` pointing at `https://github.com/Pad-Acc/hbb_common`.

- [ ] **Step 1: Confirm the GitHub CLI is authenticated**

```bash
gh auth status
```

Expected: an account with `repo` scope. If `gh` is missing, create both repos through the GitHub web UI instead — `Pad-Acc/Raatik.Remote` (already exists) and a fork of `rustdesk/hbb_common` named `Pad-Acc/hbb_common`, both **public** — then skip to Step 3.

- [ ] **Step 2: Fork hbb_common**

```bash
gh repo fork rustdesk/hbb_common --org Pad-Acc --fork-name hbb_common --clone=false
gh repo edit Pad-Acc/hbb_common --visibility public --accept-visibility-change-consequences
```

Expected: the fork exists and is public. If `Pad-Acc` is a user account rather than an org, drop `--org Pad-Acc`.

- [ ] **Step 3: Create the hbb_common branch at the pinned commit and push it**

The submodule is currently at detached HEAD `7e1c392c62d39c364127307cd408421dd5f8cfb0`, which is what the `1.4.9` tag pins (§3).

```bash
cd libs/hbb_common
git remote add raatik https://github.com/Pad-Acc/hbb_common.git
git checkout -b raatik/1.4.9
git push -u raatik raatik/1.4.9
cd ../..
```

Expected: branch `raatik/1.4.9` on the fork at commit `7e1c392`.

- [ ] **Step 4: Repoint .gitmodules at the fork**

Replace the `url` line so a fresh clone pulls RAATIK's hbb_common, not upstream's. This is the change that prevents CI silently building vanilla RustDesk (§4.1).

```ini
[submodule "libs/hbb_common"]
	path = libs/hbb_common
	url = https://github.com/Pad-Acc/hbb_common
	branch = raatik/1.4.9
```

- [ ] **Step 5: Sync the submodule config and verify**

```bash
git submodule sync libs/hbb_common
git config --file .gitmodules submodule.libs/hbb_common.url
```

Expected output: `https://github.com/Pad-Acc/hbb_common`

- [ ] **Step 6: Commit and push the baseline**

```bash
git add .gitmodules libs/hbb_common
git commit -m "build: point hbb_common submodule at the RAATIK fork"
git push -u raatik raatik/1.4.9
```

- [ ] **Step 7: Verify a fresh clone reproduces the tree**

This is §12 step 1 — the check that catches the failure mode where local edits work but CI does not.

```bash
cd "$TMPDIR" && git clone --recurse-submodules --branch raatik/1.4.9 \
  https://github.com/Pad-Acc/Raatik.Remote.git verify-clone
grep -n 'pub static ref APP_NAME' verify-clone/libs/hbb_common/src/config.rs
```

Expected: the line is present and still reads `"RustDesk"` — vanilla, because nothing has been rebranded yet. A *missing* file means the submodule wiring is broken; fix before continuing.

---

### Task 2: Green CI build of unmodified source

Per §4.2 this must pass **before** any rebranding, so that a later failure is unambiguously ours rather than the toolchain's. Deliverable: a downloadable installer built from RAATIK's repo, still branded RustDesk.

> **Executed 2026-07-25 — green on the second attempt. Two gaps in this task's original text.**
>
> 1. **A `generate-bridge` job is required and was missing entirely.** This task specified a
>    single Windows job, but the build cannot compile without the `flutter_rust_bridge`
>    generated bindings. The working workflow has two jobs: `generate-bridge` on
>    `ubuntu-22.04`, which runs the bridge codegen and uploads a `bridge-artifact`, and
>    `build-windows` on `windows-2022`, which declares `needs: [generate-bridge]` and restores
>    that artifact before building. Bridge codegen takes ~2 minutes; the Windows job ~43.
> 2. **The custom-engine step must resolve the Flutter root dynamically.** Copying upstream's
>    hardcoded `C:/hostedtoolcache/windows/flutter/stable-<ver>-x64/...` path fails with
>    `Move-Item: Could not find a part of the path`, because `subosito/flutter-action` does not
>    install to that location. The fix derives it at runtime:
>    `$flutterRoot = Split-Path (Split-Path (Get-Command flutter).Source)`, then
>    `New-Item -ItemType Directory -Force` on
>    `$flutterRoot\bin\cache\artifacts\engine\windows-x64-release` before the move.
>
> Final build command: `python3 .\build.py --portable --flutter --hwcodec --vram`. Note
> `--skip-portable-pack` is deliberately absent — CI uses it because it packs separately, but
> here the self-extracting installer is the deliverable.
>
> Result: run 30159818309 succeeded, artifact `raatikdesk-windows-x86_64`, 23,345,692 bytes,
> with `if-no-files-found: error` guarding the `./*install.exe` glob.

**Files:**
- Create: `.github/workflows/raatik-windows.yml`

**Interfaces:**
- Consumes: the pushed branch from Task 1.
- Produces: workflow `raatik-windows`, artifact name `raatikdesk-windows-x86_64`, containing `rustdesk-1.4.9-install.exe` at this stage.

- [ ] **Step 1: Write the release workflow**

Derived from `build-for-windows-flutter` ([flutter-build.yml:80](../../../.github/workflows/flutter-build.yml)), reduced to x64, signing removed, and `--skip-portable-pack` dropped so `build.py` emits the installer directly (§10.2).

```yaml
name: raatik-windows

# Manual only. This job takes 40-60 minutes because vcpkg compiles ffmpeg, aom,
# libvpx, libyuv, opus and mfx-dispatch from source. Triggering it on every push
# would burn hours of wall-clock on commits that raatik-check already validates.
# Run it deliberately: gh workflow run raatik-windows --ref raatik/1.4.9
on:
  workflow_dispatch:

env:
  RUST_VERSION: "1.75"
  LLVM_VERSION: "15.0.6"
  FLUTTER_VERSION: "3.24.5"
  VCPKG_COMMIT_ID: "120deac3062162151622ca4860575a33844ba10b"
  VERSION: "1.4.9"

jobs:
  build-windows:
    runs-on: windows-2022
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install LLVM
        uses: KyleMayes/install-llvm-action@v2
        with:
          version: ${{ env.LLVM_VERSION }}

      - name: Install Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Replace engine with rustdesk custom flutter engine
        run: |
          flutter doctor -v
          flutter precache --windows
          Invoke-WebRequest -Uri https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip -OutFile windows-x64-release.zip
          Expand-Archive -Path windows-x64-release.zip -DestinationPath windows-x64-release
          $engineDir = "$env:FLUTTER_ROOT\bin\cache\artifacts\engine\windows-x64-release"
          Move-Item -Force windows-x64-release\* $engineDir\

      - name: Patch flutter
        shell: bash
        run: |
          cp .github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff $(dirname $(dirname $(which flutter)))
          cd $(dirname $(dirname $(which flutter)))
          git apply flutter_3.24.4_dropdown_menu_enableFilter.diff

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@1.75
        with:
          targets: x86_64-pc-windows-msvc
          components: rustfmt

      - uses: Swatinem/rust-cache@v2

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11
        with:
          vcpkgDirectory: C:\vcpkg
          vcpkgGitCommitId: ${{ env.VCPKG_COMMIT_ID }}
          doNotCache: false

      - name: Install vcpkg dependencies
        shell: bash
        env:
          VCPKG_DEFAULT_HOST_TRIPLET: x64-windows-static
        run: |
          if ! $VCPKG_ROOT/vcpkg install --triplet x64-windows-static \
            --x-install-root="$VCPKG_ROOT/installed"; then
            find "${VCPKG_ROOT}/" -name "*.log" -print -exec cat {} \;
            exit 1
          fi

      - name: Build
        run: python3 .\build.py --portable --flutter --hwcodec --vram

      - name: Upload installer
        uses: actions/upload-artifact@v4
        with:
          name: raatikdesk-windows-x86_64
          path: ./*install.exe
          if-no-files-found: error
```

`vcpkgDirectory: C:\vcpkg` is on the **runner's** C:, not your machine — the "nothing on C:" constraint applies to your local machine only.

- [ ] **Step 2: Commit and push the workflow**

```bash
git add .github/workflows/raatik-windows.yml
git commit -m "ci: add Windows x64 release workflow"
git push raatik raatik/1.4.9
```

- [ ] **Step 3: Trigger the run manually and watch it**

The workflow is `workflow_dispatch` only, so pushing does not start it.

```bash
gh workflow run raatik-windows --repo Pad-Acc/Raatik.Remote --ref raatik/1.4.9
sleep 10
gh run watch --repo Pad-Acc/Raatik.Remote
```

Expected: success. Budget ~40-60 minutes for the first run; vcpkg compiles ffmpeg, aom, libvpx, libyuv, opus and mfx-dispatch from source. Subsequent runs are far faster from cache.

- [ ] **Step 4: Download and verify the artifact exists**

```bash
gh run download --repo Pad-Acc/Raatik.Remote --name raatikdesk-windows-x86_64 --dir ./ci-artifact
ls -l ./ci-artifact
```

Expected: `rustdesk-1.4.9-install.exe`. Still RustDesk-branded — correct at this stage.

- [ ] **Step 5: Install and smoke-test it**

Run the installer on a Windows machine and confirm the app launches and shows an ID. This proves the pipeline end-to-end before any rebranding.

- [ ] **Step 6: Commit nothing further; record the run URL**

Note the successful run URL in the task log. It is the baseline any later failure is compared against.

---

### Task 3: Fast `cargo check` workflow

Restores an inner feedback loop, since there is no local toolchain (§10.1). Build this before editing code so every later task has minutes-long feedback instead of a 40-minute round trip.

**Files:**
- Create: `.github/workflows/raatik-check.yml`

**Interfaces:**
- Produces: workflow `raatik-check`, which runs `cargo check` and `cargo test -p hbb_common`.

- [ ] **Step 1: Write the check workflow**

The root crate needs vcpkg **transitively**, via the `scrap` workspace member: [libs/scrap/build.rs:82](../../../libs/scrap/build.rs) panics without `VCPKG_ROOT`. `hbb_common` needs none — it does not depend on `scrap`, and its own `build.rs` only runs pure-Rust protobuf codegen — so its tests run first as a seconds-level fail-fast gate.

> **Correction (2026-07-25):** this line previously blamed [build.rs:62](../../../build.rs)'s `std::env::var("VCPKG_ROOT").unwrap()`. That call is inside `install_android_deps()`, which returns early when `CARGO_CFG_TARGET_OS != "android"` (`build.rs:46-50`), so it never runs on a `windows-msvc` build. The conclusion (the root-crate job needs vcpkg) is unchanged; the cited cause was wrong.

```yaml
name: raatik-check

on:
  workflow_dispatch:
  push:
    branches: [raatik/1.4.9]
  pull_request:

jobs:
  hbb-common-tests:
    runs-on: windows-2022
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: dtolnay/rust-toolchain@1.75
      - uses: Swatinem/rust-cache@v2
      - name: Test hbb_common (no vcpkg needed)
        run: cargo test -p hbb_common --lib

  cargo-check:
    runs-on: windows-2022
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Install LLVM
        uses: KyleMayes/install-llvm-action@v2
        with:
          version: "15.0.6"
      - uses: dtolnay/rust-toolchain@1.75
        with:
          targets: x86_64-pc-windows-msvc
      - uses: Swatinem/rust-cache@v2
      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11
        with:
          vcpkgDirectory: C:\vcpkg
          vcpkgGitCommitId: "120deac3062162151622ca4860575a33844ba10b"
          doNotCache: false
      - name: Install vcpkg dependencies
        shell: bash
        env:
          VCPKG_DEFAULT_HOST_TRIPLET: x64-windows-static
        run: $VCPKG_ROOT/vcpkg install --triplet x64-windows-static --x-install-root="$VCPKG_ROOT/installed"
      - name: Test root crate
        run: cargo test --features flutter --lib
```

`cargo test` rather than `cargo check`: it compiles the same code *and* executes the
`#[cfg(test)]` tests that Tasks 7, 8, 9 and 10 add to `src/common.rs` and `src/lang.rs`.
With `cargo check` those tests would never run, making every "verify they pass" step in
this plan unverifiable.

- [ ] **Step 2: Push and confirm both jobs pass**

```bash
git add .github/workflows/raatik-check.yml
git commit -m "ci: add fast cargo check and hbb_common test workflow"
git push raatik raatik/1.4.9
gh run watch --repo Pad-Acc/Raatik.Remote
```

Expected: `hbb-common-tests` green in a few minutes; `cargo-check` green once vcpkg is cached.

---

### Task 4: Brand the app name and organization in hbb_common

The single highest-leverage change (§5.1). Work happens in `libs/hbb_common`, which is Fork A — a **separate repository**. Commits go there, then the parent's submodule pointer is updated.

**Files:**
- Modify: `libs/hbb_common/src/config.rs:57` and `:72`
- Test: `libs/hbb_common/src/config.rs` — the existing `mod tests` at line 3279

**Interfaces:**
- Produces: `APP_NAME` defaulting to `"RaatikDesk"` and `ORG` to `"ir.raatik"`. Every later task depends on these: `get_app_name()`, `get_uri_prefix()`, the config directory, and the `lang.rs` substitution all read `APP_NAME`.

- [ ] **Step 1: Write the failing tests**

Add to the existing `mod tests` in `libs/hbb_common/src/config.rs`. It already has `use super::*;`, so the statics are in scope.

```rust
    #[test]
    fn test_app_name_is_raatikdesk() {
        assert_eq!(APP_NAME.read().unwrap().as_str(), "RaatikDesk");
    }

    #[test]
    fn test_org_is_raatik() {
        assert_eq!(ORG.read().unwrap().as_str(), "ir.raatik");
    }
```

- [ ] **Step 2: Run them to verify they fail**

```bash
cd libs/hbb_common
cargo test -p hbb_common --lib test_app_name_is_raatikdesk test_org_is_raatik
```

Expected: FAIL — `assertion `left == right` failed: left: "RustDesk", right: "RaatikDesk"`.

If `cargo` is unavailable locally (expected — no local toolchain), push to a scratch branch and read the `hbb-common-tests` job instead. Confirm it is **red** before proceeding.

- [ ] **Step 3: Change the two defaults**

In `libs/hbb_common/src/config.rs`, line 57:

```rust
    pub static ref ORG: RwLock<String> = RwLock::new("ir.raatik".to_owned());
```

and line 72:

```rust
    pub static ref APP_NAME: RwLock<String> = RwLock::new("RaatikDesk".to_owned());
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cargo test -p hbb_common --lib test_app_name_is_raatikdesk test_org_is_raatik
```

Expected: PASS, 2 passed.

- [ ] **Step 5: Run the whole hbb_common suite for regressions**

`APP_NAME` feeds the config-directory logic at `config.rs:743` and `:798`, so path-related tests are the ones at risk.

```bash
cargo test -p hbb_common --lib
```

Expected: all pass. Any failure here is a genuine consequence of the rename — fix it, do not weaken the test.

- [ ] **Step 6: Commit in the submodule and push**

```bash
cd libs/hbb_common
git add src/config.rs
git commit -m "feat: brand APP_NAME as RaatikDesk and ORG as ir.raatik"
git push raatik raatik/1.4.9
cd ../..
```

- [ ] **Step 7: Update the parent's submodule pointer and commit**

Forgetting this is the single easiest way to make CI build vanilla RustDesk while local edits look correct.

```bash
git add libs/hbb_common
git commit -m "build: bump hbb_common to branded APP_NAME and ORG"
git push raatik raatik/1.4.9
```

---

### Task 5: Compile in RAATIK's server defaults

**Files:**
- Modify: `libs/hbb_common/src/config.rs:120-121`
- Test: `libs/hbb_common/src/config.rs` — `mod tests`

**Interfaces:**
- Consumes: nothing from Task 4; independent.
- Produces: `RENDEZVOUS_SERVERS == &["remote.raatik.ir"]`, `RS_PUB_KEY == "Hl+uz02ouYRm03N9u9z9blRdHY0B9NYDPvqp7kYfcRs="`.

- [ ] **Step 1: Write the failing tests**

```rust
    #[test]
    fn test_rendezvous_server_is_raatik() {
        assert_eq!(RENDEZVOUS_SERVERS, &["remote.raatik.ir"]);
    }

    #[test]
    fn test_rs_pub_key_is_raatik() {
        assert_eq!(RS_PUB_KEY, "Hl+uz02ouYRm03N9u9z9blRdHY0B9NYDPvqp7kYfcRs=");
    }
```

- [ ] **Step 2: Run them to verify they fail**

```bash
cargo test -p hbb_common --lib test_rendezvous_server_is_raatik test_rs_pub_key_is_raatik
```

Expected: FAIL — currently `rs-ny.rustdesk.com` and `OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=`.

- [ ] **Step 3: Replace the two constants**

`libs/hbb_common/src/config.rs`, lines 120-121:

```rust
pub const RENDEZVOUS_SERVERS: &[&str] = &["remote.raatik.ir"];
pub const RS_PUB_KEY: &str = "Hl+uz02ouYRm03N9u9z9blRdHY0B9NYDPvqp7kYfcRs=";
```

The slice stays one element, exactly as upstream, so the `[0]` index and empty `[1..]` slice at [src/client.rs:299-300](../../../src/client.rs) behave unchanged (§6). Leave `PROD_RENDEZVOUS_SERVER` at line 70 alone — it has no writer anywhere and is dead code.

Do **not** set a relay: `hbbs` runs with `-r remote.raatik.ir` and hands the relay address to clients (§3.1).

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cargo test -p hbb_common --lib
```

Expected: all pass.

- [ ] **Step 5: Commit in the submodule, bump the parent pointer, push both**

```bash
cd libs/hbb_common
git add src/config.rs
git commit -m "feat: compile in remote.raatik.ir and RAATIK public key"
git push raatik raatik/1.4.9
cd ../..
git add libs/hbb_common
git commit -m "build: bump hbb_common to RAATIK server defaults"
git push raatik raatik/1.4.9
```

---

### Task 6: Rewrite hbb_common's outbound URLs

**Files:**
- Modify: `libs/hbb_common/src/config.rs:100-103`
- Test: `libs/hbb_common/src/config.rs` — `mod tests`

**Interfaces:**
- Produces: `LINK_DOCS_HOME`, `LINK_DOCS_X11_REQUIRED`, `LINK_HEADLESS_LINUX_SUPPORT` all `https://raatik.com`.

- [ ] **Step 1: Write the failing test**

```rust
    #[test]
    fn test_no_rustdesk_urls_in_helper_links() {
        for url in [
            LINK_DOCS_HOME,
            LINK_DOCS_X11_REQUIRED,
            LINK_HEADLESS_LINUX_SUPPORT,
        ] {
            assert!(
                !url.contains("rustdesk"),
                "brand leaked in outbound URL: {url}"
            );
            assert!(url.starts_with("https://raatik.com"), "unexpected URL: {url}");
        }
    }
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cargo test -p hbb_common --lib test_no_rustdesk_urls_in_helper_links
```

Expected: FAIL — `brand leaked in outbound URL: https://rustdesk.com/docs/en/`.

- [ ] **Step 3: Rewrite the three constants**

`libs/hbb_common/src/config.rs`, lines 100-103. Flattened to the site root, not mirrored as `/docs/en/...`, because RAATIK hosts no docs tree and a 404 is worse than a landing page (§8.3).

```rust
pub const LINK_DOCS_HOME: &str = "https://raatik.com";
pub const LINK_DOCS_X11_REQUIRED: &str = "https://raatik.com";
pub const LINK_HEADLESS_LINUX_SUPPORT: &str = "https://raatik.com";
```

Leave the `HELPER_URL` HashMap **keys** (`"rustdesk docs home"` etc., lines 106-109) untouched — they are internal lookup identifiers passed from `src/`, never rendered, and changing them would break callers.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cargo test -p hbb_common --lib
```

Expected: all pass.

- [ ] **Step 5: Commit in the submodule, bump the parent pointer, push both**

```bash
cd libs/hbb_common
git add src/config.rs
git commit -m "feat: point outbound help links at raatik.com"
git push raatik raatik/1.4.9
cd ../..
git add libs/hbb_common
git commit -m "build: bump hbb_common to raatik.com help links"
git push raatik raatik/1.4.9
```

---

### Task 7: Fix the literals that bypass `get_app_name()`

Implements §5.2. Back in Fork B (the main repo) from here on, unless a step says otherwise.

**Files:**
- Modify: `src/auth_2fa.rs:17`, `src/ipc/auth.rs:1017,1021`, `src/platform/windows.rs:1992`, `src/plugin/mod.rs:142`
- Test: `src/common.rs` — the existing `mod tests`

**Interfaces:**
- Consumes: `APP_NAME` from Task 4.
- Produces: no hardcoded `"RustDesk"` outside the §8.3 allowlist.

- [ ] **Step 1: Write the failing tests**

Add to the existing `mod tests` in `src/common.rs`.

```rust
    #[test]
    fn test_uri_prefix_is_raatikdesk() {
        assert_eq!(get_uri_prefix(), "raatikdesk://");
    }

    #[test]
    fn test_is_rustdesk_is_false() {
        assert!(!is_rustdesk());
    }

    #[test]
    fn test_is_custom_client_is_true() {
        assert!(is_custom_client());
    }

    #[test]
    fn test_2fa_issuer_is_branded() {
        assert_eq!(crate::auth_2fa::ISSUER, "RaatikDesk");
    }
```

`ISSUER` is currently private; add `pub(crate)` to it in the next step so the test can see it.

- [ ] **Step 2: Run them to verify they fail**

These live in the root crate, so they need vcpkg. Push to a scratch branch and read the `cargo-check` workflow, or add a `cargo test --lib` step to it temporarily.

Expected: FAIL — `test_uri_prefix_is_raatikdesk` yields `rustdesk://` until Task 4's submodule bump is in place, and `test_2fa_issuer_is_branded` does not compile until `ISSUER` is visible.

- [ ] **Step 3: Change the four literals**

`src/auth_2fa.rs:17` — the name shown in authenticator apps:

```rust
pub(crate) const ISSUER: &str = "RaatikDesk";
```

`src/ipc/auth.rs:1017` and `:1021` — replace both `OsStr::new("RustDesk")` occurrences:

```rust
            Some(std::ffi::OsStr::new("RaatikDesk")),
```

`src/platform/windows.rs:1992` — derive from `get_app_name()` rather than hardcoding, so it tracks `APP_NAME`:

```rust
#[inline]
pub fn get_custom_client_staging_dir() -> PathBuf {
    let app_name = crate::get_app_name();
    get_public_base_dir()
        .join(&app_name)
        .join(format!("{app_name}CustomClientStaging"))
}
```

`src/plugin/mod.rs:142` — same treatment:

```rust
        .join(crate::get_app_name())
```

- [ ] **Step 4: Run the tests to verify they pass**

Expected: 4 passed.

- [ ] **Step 5: Confirm `test_is_public` still passes untouched**

This is the regression guard for the §8.3 decision not to rewrite `is_public()`.

```bash
cargo test --lib test_is_public
```

Expected: PASS, with `src/common.rs:2768-2808` unmodified — including the `rustdesk.computer.com` fixture.

- [ ] **Step 6: Commit**

```bash
git add src/auth_2fa.rs src/ipc/auth.rs src/platform/windows.rs src/plugin/mod.rs src/common.rs
git commit -m "feat: brand literals that bypass get_app_name()"
git push raatik raatik/1.4.9
```

---

### Task 8: Audit the seven `is_custom_client()` call sites

`is_custom_client()` flips from `false` to `true` as a side effect of Task 4 (§5.3). This task is an audit with a written record, not a code change — unless a site's new behaviour turns out to be unwanted.

**Files:**
- Read: `src/common.rs:942`, `src/ipc.rs:868`, `src/flutter_ffi.rs:2475,2861`, `src/platform/windows.rs:1483,2106,2239`
- Create: `raatik/is_custom_client_audit.md`

**Interfaces:**
- Consumes: `APP_NAME` from Task 4.
- Produces: `raatik/is_custom_client_audit.md`, satisfying §12 step 5.

- [ ] **Step 1: Record what each site now does**

Create `raatik/is_custom_client_audit.md` with one section per site: the code, what changes when the predicate is `true`, and a verdict of `desirable` or `needs-patch`. One is already known:

```markdown
## src/common.rs:942 — check_software_update()

`check_software_update()` returns early when `is_custom_client()` is true, so
RaatikDesk never contacts `https://api.rustdesk.com/version/latest`.

Verdict: **desirable**. No phone-home to RustDesk and no third-party telemetry
about RAATIK's customers. Accepted cost: no in-app update notification;
versions are distributed to customers manually (spec §8.3, §11).
```

- [ ] **Step 2: Add a test pinning the update-check behaviour**

In `src/common.rs`'s `mod tests`:

```rust
    #[test]
    fn test_update_check_disabled_for_custom_client() {
        // check_software_update() early-returns for custom clients, so no
        // request is ever made to RustDesk's version endpoint.
        assert!(is_custom_client());
    }
```

- [ ] **Step 3: Patch any site whose new behaviour is unwanted**

If a site's verdict is `needs-patch`, change that site explicitly. Do **not** revert `APP_NAME` — that would undo the entire rebrand.

- [ ] **Step 4: Run the suite**

```bash
cargo test --lib
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add raatik/is_custom_client_audit.md src/common.rs
git commit -m "docs: audit is_custom_client call sites after APP_NAME change"
git push raatik raatik/1.4.9
```

---

### Task 9: Reduce languages to English and Farsi, default Farsi

**Files:**
- Delete: 49 files in `src/lang/` (all except `en.rs`, `fa.rs`, `template.rs`)
- Modify: `src/lang.rs` — `mod` declarations (lines 4-51), the `match` arms feeding `translate`, and `LANGS` (line 52)
- Modify: `flutter/lib/common.dart:649` — `supportedLocales`
- Modify: `src/lang/fa.rs` — the one empty value
- Test: `src/lang.rs` — new `mod tests`

**Interfaces:**
- Consumes: `APP_NAME` from Task 4 for the substitution test.
- Produces: `LANGS == &[("en", "English"), ("fa", "فارسی")]`.

- [ ] **Step 1: Write the failing tests**

`src/lang.rs` has no test module; add one at the end of the file.

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_only_english_and_farsi() {
        assert_eq!(LANGS.len(), 2);
        assert_eq!(LANGS[0].0, "en");
        assert_eq!(LANGS[1].0, "fa");
    }

    #[test]
    fn test_brand_substituted_in_english() {
        // en.rs: ("connecting_status", "Connecting to the RustDesk network...")
        let s = translate_locale("connecting_status".to_owned(), "en");
        assert!(s.contains("RaatikDesk"), "not substituted: {s}");
        assert!(!s.contains("RustDesk"), "brand leaked: {s}");
    }

    #[test]
    fn test_farsi_has_no_empty_values() {
        for (k, v) in fa::T.iter() {
            assert!(!v.is_empty(), "untranslated Farsi key: {k}");
        }
    }
}
```

Confirm the real name of the locale-taking translate function before running — read `src/lang.rs` and use it verbatim rather than assuming `translate_locale`.

- [ ] **Step 2: Run them to verify they fail**

Expected: FAIL — `LANGS.len()` is far more than 2.

- [ ] **Step 3: Delete the 49 language files**

```bash
cd src/lang
ls *.rs | grep -vE '^(en|fa|template)\.rs$' | xargs git rm
cd ../..
```

Expected: 49 files removed; `en.rs`, `fa.rs`, `template.rs` remain. `template.rs` is never edited (`AGENTS.md`).

- [ ] **Step 4: Prune `src/lang.rs`**

Remove the 49 `mod` declarations, leaving only `mod en;` and `mod fa;`. Reduce `LANGS` to:

```rust
pub const LANGS: &[(&str, &str)] = &[("en", "English"), ("fa", "فارسی")];
```

Then reduce the `match` on locale (around lines 200-218) to `fa` plus the `_ => en::T.deref()` fallback. Every deleted `mod` must lose its match arm too, or compilation fails.

- [ ] **Step 5: Make Farsi the default**

Resolve §13's open item: find where the initial locale is chosen when no preference is stored — the fallback currently resolves to the OS locale or `en`. Change that fallback to `fa`. Record the exact file and line in the commit message.

- [ ] **Step 6: Trim Flutter's supported locales**

`flutter/lib/common.dart:649`:

```dart
List<Locale> supportedLocales = const [
  Locale('en'),
  Locale('fa'),
];
```

Do **not** add a `Directionality` wrapper. Farsi renders in the existing LTR layout by decision (§7).

- [ ] **Step 7: Fill the single empty Farsi value**

Find it and translate the English source, preserving any `{}` placeholders and escapes exactly:

```bash
grep -n ', "")' src/lang/fa.rs
```

Expected before: one match. After the fix: none.

- [ ] **Step 8: Run the tests to verify they pass**

```bash
cargo test --lib
```

Expected: the three new tests pass and nothing else regresses.

- [ ] **Step 9: Commit**

```bash
git add -A src/lang src/lang.rs flutter/lib/common.dart
git commit -m "feat: reduce languages to English and Farsi, default Farsi"
git push raatik raatik/1.4.9
```

---

### Task 10: Rewrite the remaining URLs and the two exempted strings

Covers §8.3's rewrite list in the main repo, plus the substitution exclusions found at [lang.rs:227-228](../../../src/lang.rs).

**Files:**
- Modify: `src/lang/en.rs` — the 8 `doc_*` URLs, `powered_by_me`, `upgrade_rustdesk_server_pro_to_{}_tip`
- Modify: `src/lang/fa.rs` — the same keys
- Modify: `src/lang.rs:227-228` — the exclusion condition
- Test: `src/lang.rs` — `mod tests`

**Interfaces:**
- Consumes: `LANGS` from Task 9.
- Produces: no `rustdesk` substring in any language-file value.

- [ ] **Step 1: Write the failing tests**

The test must check **translated output**, not raw table values. Raw values legitimately
contain `RustDesk` — `fa.rs:629` stores `("About RustDesk", "RustDesk درباره")` and the
substitution rewrites it at lookup time. Asserting on raw values would flag every
correctly-handled string.

`fa.rs` carries the full 764-key set, so iterating its keys covers everything. Note
`template.rs` is **not** a compiled module — it is a reference file only and cannot be
iterated.

```rust
    #[test]
    fn test_no_brand_leak_in_translated_output() {
        for (k, _) in fa::T.iter() {
            for locale in ["en", "fa"] {
                let out = translate_locale(k.to_string(), locale);
                assert!(
                    !out.contains("RustDesk"),
                    "brand leaked for key {k} in {locale}: {out}"
                );
            }
        }
    }

    #[test]
    fn test_powered_by_is_branded() {
        let s = translate_locale("powered_by_me".to_owned(), "en");
        assert_eq!(s, "Powered by RaatikDesk");
    }
```

- [ ] **Step 2: Run them to verify they fail**

Expected: FAIL — `brand leaked for key powered_by_me`, because that key is exempted from
substitution at `lang.rs:228`.

`translate_locale` calls `resolve_lang`, which reads the saved `lang` option and can
override the `locale` argument. If a stored preference makes the test ambiguous, clear it
in the test or assert against both locales as written.

- [ ] **Step 3: Rewrite the URL values in en.rs and fa.rs**

Every `doc_*` value and the `id-relay-set` blog link becomes `https://raatik.com`. For example `src/lang/en.rs:92`:

```rust
        ("doc_mac_permission", "https://raatik.com"),
```

Copy each URL identically into `fa.rs` — `AGENTS.md` requires URL values be copied verbatim rather than translated.

- [ ] **Step 4: Brand the two exempted strings**

`src/lang/en.rs:214` and `src/lang/fa.rs:583`:

```rust
        ("powered_by_me", "Powered by RaatikDesk"),
```

And `src/lang/en.rs:197`, with the Farsi equivalent at `fa.rs:544`:

```rust
        ("upgrade_rustdesk_server_pro_to_{}_tip", "Please upgrade RaatikDesk Server Pro to version {} or newer!"),
```

Keep the **key** `upgrade_rustdesk_server_pro_to_{}_tip` unchanged — it is thrown by string literal at [group_model.dart:189](../../../flutter/lib/models/group_model.dart) and renaming it breaks the lookup.

- [ ] **Step 5: Drop the now-redundant exclusions**

`src/lang.rs:227-228` skipped substitution for these two keys. With the values themselves branded, the exclusion is dead weight — but removing it is only safe once no value contains `RustDesk`, which Step 3's test now guarantees. Delete both conditions so the branch reads:

```rust
        if !crate::is_rustdesk() {
            if s.contains("RustDesk") {
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cargo test --lib
```

Expected: all pass, including Task 9's tests.

- [ ] **Step 7: Commit**

```bash
git add src/lang/en.rs src/lang/fa.rs src/lang.rs
git commit -m "feat: point doc links at raatik.com and brand exempted strings"
git push raatik raatik/1.4.9
```

---

### Task 11: Windows executable identity and icons

**Files:**
- Modify: `flutter/windows/runner/Runner.rc:92-98`
- Modify: `flutter/windows/CMakeLists.txt:3,7`
- Modify: `Cargo.toml` — `description`, `authors`
- Replace: `res/icon.ico`, `res/32x32.png`, `res/64x64.png`, `res/128x128.png`, `res/128x128@2x.png`, `res/tray-icon.ico`, `res/logo.svg`, `flutter/windows/runner/resources/app_icon.ico`

**Interfaces:**
- Produces: a Flutter runner binary named `raatikdesk.exe`, consumed by Task 12's packaging step.

- [ ] **Step 1: Set the version resource**

`flutter/windows/runner/Runner.rc`, lines 92-98. Latin form only — the block declares `Translation, 0x409, 1252`, and codepage 1252 cannot encode Farsi (§8.2). Keep the `©`, which cp1252 does represent.

```rc
            VALUE "CompanyName", "Rayan Etemad Tosee Yekta (RAATIK)" "\0"
            VALUE "FileDescription", "RaatikDesk Remote Desktop" "\0"
            VALUE "InternalName", "raatikdesk" "\0"
            VALUE "LegalCopyright", "Copyright © 2026 Rayan Etemad Tosee Yekta (RAATIK). All rights reserved." "\0"
            VALUE "OriginalFilename", "raatikdesk.exe" "\0"
            VALUE "ProductName", "RaatikDesk" "\0"
```

- [ ] **Step 2: Rename the Flutter runner binary**

`flutter/windows/CMakeLists.txt`, lines 3 and 7. This is the customer-visible executable, so it **is** renamed — unlike the Rust crate names (§8.1).

```cmake
project(raatikdesk LANGUAGES CXX)
```

```cmake
set(BINARY_NAME "raatikdesk")
```

Leave line 106's `librustdesk.dll` and line 108's `RENAME librustdesk.dll` **unchanged** — `main.cpp:25` loads that exact filename via `LoadLibraryA`.

- [ ] **Step 3: Update Cargo metadata without renaming the crate**

`Cargo.toml` — change only these two fields. `name = "rustdesk"` and `[lib] name = "librustdesk"` stay exactly as they are (§8.1).

```toml
description = "RaatikDesk Remote Desktop"
authors = ["Rayan Etemad Tosee Yekta (RAATIK)"]
```

- [ ] **Step 4: Generate the icons from raatik-logo.png**

Pillow is not installed. Install it to a D: target so nothing lands on C:, per the user's constraint:

```bash
pip install --target D:/dev/pylibs Pillow
export PYTHONPATH=D:/dev/pylibs
```

Then run this script, which writes every required size from the single source logo:

```python
from PIL import Image

SRC = r"D:\Projects\RAATIK\RaatikRemote\raatik-logo.png"
RES = r"D:\Projects\RAATIK\RaatikRemote\rustdesk\res"
RUNNER = r"D:\Projects\RAATIK\RaatikRemote\rustdesk\flutter\windows\runner\resources"

src = Image.open(SRC).convert("RGBA")

for size, name in [(32, "32x32.png"), (64, "64x64.png"),
                   (128, "128x128.png"), (256, "128x128@2x.png")]:
    src.resize((size, size), Image.LANCZOS).save(f"{RES}\\{name}")

ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
src.save(f"{RES}\\icon.ico", sizes=ico_sizes)
src.save(f"{RES}\\tray-icon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
src.save(f"{RUNNER}\\app_icon.ico", sizes=ico_sizes)
print("icons written")
```

- [ ] **Step 5: Verify every icon was written at the right size**

```bash
python -c "
from PIL import Image
import glob
for p in glob.glob(r'D:\Projects\RAATIK\RaatikRemote\rustdesk\res\*.png') + \
         glob.glob(r'D:\Projects\RAATIK\RaatikRemote\rustdesk\res\*.ico'):
    print(p.split(chr(92))[-1], Image.open(p).size)
"
```

Expected: `32x32.png (32, 32)`, `64x64.png (64, 64)`, `128x128.png (128, 128)`,
`128x128@2x.png (256, 256)`, and the `.ico` files reporting their largest embedded size.

Leave `res/logo.svg` alone unless RAATIK has a vector logo — it is not consumed by the
Windows build, and a raster PNG renamed to `.svg` would be worse than the status quo.

- [ ] **Step 6: Add the Farsi company name to the About dialog**

This is where the Farsi form lives, since `Runner.rc` cannot encode it (§8.2). The About
card is built by `_AboutState` at
[flutter/lib/desktop/pages/desktop_setting_page.dart:2409](../../../flutter/lib/desktop/pages/desktop_setting_page.dart);
its title is `translate('About RustDesk')` at line 2434, which the runtime substitution
already turns into "About RaatikDesk" — leave that call untouched.

Add a company attribution row inside the existing `Column`, alongside the Version and
Build Date rows:

```dart
              SelectionArea(
                  child: Text('رایان اعتماد توسعه یکتا (راتیک)')
                      .marginSymmetric(vertical: 4.0)),
```

Flutter renders the Farsi glyphs natively. Do not wrap it in `Directionality` — layout
stays LTR by decision (§7).

- [ ] **Step 7: Push and confirm the check workflow still passes**

```bash
git add flutter/windows/runner/Runner.rc flutter/windows/CMakeLists.txt Cargo.toml res \
  flutter/windows/runner/resources flutter/lib/desktop/pages/desktop_setting_page.dart
git commit -m "feat: brand Windows executable identity, icons and About dialog"
git push raatik raatik/1.4.9
gh run watch --repo Pad-Acc/Raatik.Remote
```

Expected: green. Neither the CMake `BINARY_NAME` change nor the Dart edit is exercised by `cargo check`, so Task 12's full build is what actually validates them.

---

### Task 12: Name the installer RaatikDesk

**Files:**
- Modify: `build.py:466` and the `generate.py` invocation at `build.py:457`

**Interfaces:**
- Consumes: `raatikdesk.exe` from Task 11.
- Produces: `RaatikDesk-1.4.9-install.exe`.

- [ ] **Step 1: Point the portable packer at the renamed executable**

`build.py`, inside `build_flutter_windows()`. The `-e` argument must match Task 11's `BINARY_NAME`, or packing fails with a missing-file error.

```python
    system2(
        f'python3 ./generate.py -f ../../{flutter_build_dir_2} -o . -e ../../{flutter_build_dir_2}/raatikdesk.exe')
```

- [ ] **Step 2: Rename the output artifact**

`build.py:466` and the following `print`:

```python
    os.rename('./rustdesk_portable.exe', f'./RaatikDesk-{version}-install.exe')
```

The name **must** still end in `install.exe`: `is_setup()` at [src/common.rs:2306](../../../src/common.rs) decides whether to run in installer mode via `name.to_lowercase().ends_with("install.exe")`. `RaatikDesk-1.4.9-install.exe` satisfies this.

- [ ] **Step 3: Rename the portable extraction directory**

`libs/portable/src/main.rs:20` defines `APP_PREFIX`, used at line 74 as `dir.join(APP_PREFIX)` — the directory the installer extracts into, which **is** visible to customers on disk. Rename it:

```rust
const APP_PREFIX: &str = "raatikdesk";
```

- [ ] **Step 4: Leave the packer's binary format marker alone**

`generate.py` writes the literal `"rustdesk"` at lines 42 and 57 as a **start and end sentinel** in `data.bin`, and `libs/portable/src/bin_reader.rs:76,82` validates that exact string when unpacking. It is an internal container-format magic value, never rendered.

Changing it requires editing both sides in lockstep for zero customer-visible benefit, and a mismatch produces a corrupt installer. **Leave both unchanged** and allowlist the string in Task 13 instead. Also leave `generate.py:100`'s default `-e` value — Step 1 passes `-e` explicitly, so the default is never used.

Note `libs/portable/src/main.rs:219,235` reference `RuntimeBroker_rustdesk.exe`, the helper binary from the third-party TempTopMostWindow project. Renaming it would require rebuilding that external artifact, which is out of scope; it is allowlisted in Task 13 and noted as known residue.

- [ ] **Step 5: Run the full release workflow**

`generate.py` is deliberately **not** staged — Step 4 leaves it unchanged.

```bash
git add build.py libs/portable/src/main.rs
git commit -m "build: produce RaatikDesk-1.4.9-install.exe"
git push raatik raatik/1.4.9
gh workflow run raatik-windows --repo Pad-Acc/Raatik.Remote --ref raatik/1.4.9
sleep 10
gh run watch --repo Pad-Acc/Raatik.Remote
```

Expected: `raatik-windows` green, artifact contains `RaatikDesk-1.4.9-install.exe`.

- [ ] **Step 6: Record the run URL**

---

### Task 13: Brand-leak gate in CI

Automates §12 step 3 so a leak fails the build rather than relying on someone remembering to look.

**Files:**
- Create: `raatik/no_leak_gate.py`
- Modify: `.github/workflows/raatik-windows.yml`

**Interfaces:**
- Consumes: the built artifact from Task 12.
- Produces: a gate that exits non-zero on any `RustDesk` or `rustdesk.com` occurrence outside an explicit allowlist.

- [ ] **Step 1: Write the gate with a failing allowlist test**

`raatik/no_leak_gate.py`. The allowlist is the point — a blanket pass would be worthless (§12).

```python
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
```

The two checks differ deliberately. The runner executable is held to zero unallowlisted
occurrences. The installer tolerates at most two, because the container sentinel is a bare
literal with no distinguishing context — and since the bundled payload is compressed, no
other plaintext brand string should survive there. If the installer count exceeds two,
something genuinely leaked.

- [ ] **Step 2: Verify it fails on a known-bad input**

```bash
printf 'window title: RustDesk Remote Desktop' > /tmp/leaky.bin
python3 raatik/no_leak_gate.py /tmp/leaky.bin
```

Expected: exit 1, `FAIL: 1 brand leak(s)`.

- [ ] **Step 3: Verify it passes on allowlisted residue**

```bash
printf 'LoadLibraryA librustdesk.dll and https://api.rustdesk.com/version/latest' > /tmp/ok.bin
python3 raatik/no_leak_gate.py /tmp/ok.bin
```

Expected: exit 0, `OK: no brand leak`.

- [ ] **Step 4: Verify the installer path tolerates sentinels but not a third occurrence**

The filename must end in `install.exe` to select `check_installer()`.

```bash
printf 'rustdesk\x00payload\x00rustdesk' > /tmp/a-install.exe
python3 raatik/no_leak_gate.py /tmp/a-install.exe
printf 'rustdesk\x00payload\x00rustdesk\x00window title RustDesk' > /tmp/b-install.exe
python3 raatik/no_leak_gate.py /tmp/b-install.exe
```

Expected: the first exits 0 with `OK: 2 sentinel(s) only`; the second exits 1 with
`FAIL: 3 brand occurrence(s)`.

- [ ] **Step 5: Wire it into the release workflow**

Add before the upload step in `.github/workflows/raatik-windows.yml`:

```yaml
      - name: Brand-leak gate
        shell: bash
        run: |
          python3 raatik/no_leak_gate.py \
            ./flutter/build/windows/x64/runner/Release/raatikdesk.exe \
            ./RaatikDesk-${{ env.VERSION }}-install.exe
```

- [ ] **Step 6: Push and confirm the gate runs and passes**

```bash
git add raatik/no_leak_gate.py .github/workflows/raatik-windows.yml
git commit -m "ci: fail the build on user-visible RustDesk brand leaks"
git push raatik raatik/1.4.9
gh workflow run raatik-windows --repo Pad-Acc/Raatik.Remote --ref raatik/1.4.9
sleep 10
gh run watch --repo Pad-Acc/Raatik.Remote
```

Expected: the gate step reports `OK` for both files. If it reports a leak, that is a genuine finding — fix the source, do not widen the allowlist without recording why in the spec.

---

### Task 14: End-to-end verification on real machines

Closes out §12. Nothing here is inferred from a green build.

**Files:**
- Create: `raatik/verification-2026-07-25.md`

**Interfaces:**
- Consumes: the artifact from Task 13.

- [ ] **Step 1: Install the CI artifact on a clean Windows machine**

```bash
gh run download --repo Pad-Acc/Raatik.Remote --name raatikdesk-windows-x86_64 --dir ./release
```

Install the downloaded `RaatikDesk-1.4.9-install.exe`. Expect a SmartScreen "unknown publisher" warning — that is accepted, since the build is unsigned (§9).

- [ ] **Step 2: Verify the runtime checklist**

Record each result in `raatik/verification-2026-07-25.md`:

- Farsi is the language on first launch; English is selectable.
- Window title, tray tooltip, Start Menu entry and About dialog all read RaatikDesk.
- The About dialog shows the Farsi company name رایان اعتماد توسعه یکتا (راتیک).
- "Powered by RaatikDesk" appears where the attribution string renders.
- The config directory is `%APPDATA%\RaatikDesk`.
- The client registers with `remote.raatik.ir` with no manual configuration and displays an ID.
- The Network settings pane is visible and editable, with ID server prefilled and Relay empty.
- No `rustdesk` entries under `%APPDATA%` or in the Start Menu.

- [ ] **Step 3: Verify the URL audit**

Confirm `https://raatik.com/privacy` resolves, and that no in-app link opens a `rustdesk.com` page. If the privacy page is not yet hosted, record it as a release blocker (§8.3).

- [ ] **Step 4: Run a remote-control session between two machines**

Install on a second Windows machine and connect through `remote.raatik.ir`. Confirm connection establishment, keyboard and mouse input, screen capture, and clipboard.

- [ ] **Step 5: Confirm the customer-ID consequence**

On a machine that previously ran `rustdesk-1.4.8-x86_64.exe`, confirm RaatikDesk installs alongside it with a **different** ID (§5.4). This is expected, not a bug — record it so rollout comms can be planned.

- [ ] **Step 6: Commit the verification record**

```bash
git add raatik/verification-2026-07-25.md
git commit -m "docs: record end-to-end verification results"
git push raatik raatik/1.4.9
```

---

## Post-plan release blockers

Neither is a code change; both must be resolved before shipping to customers.

1. **Host `https://raatik.com/privacy`** — linked from the About dialog (§8.3).
2. **Plan the ID migration comms** — every existing customer gets a new device ID (§5.4).
