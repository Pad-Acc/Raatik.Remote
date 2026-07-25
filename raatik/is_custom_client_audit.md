# Why `is_rustdesk()` / `is_custom_client()` matter, and what each call site does

RaatikDesk builds this codebase with `APP_NAME` set to `"RaatikDesk"` instead of the
upstream default `"RustDesk"` (see `libs/hbb_common/src/config.rs`). Two predicates in
`src/common.rs` are defined directly in terms of that string, so changing it flips both
of them for every build, everywhere, with no other code change required:

```rust
// src/common.rs
pub fn is_rustdesk() -> bool {
    hbb_common::config::APP_NAME.read().unwrap().eq("RustDesk")
}

pub fn is_custom_client() -> bool {
    get_app_name() != "RustDesk"
}
```

For RaatikDesk: `is_rustdesk()` is `false` and `is_custom_client()` is `true`, always.
Both predicates are pinned by tests (`src/common.rs`: `test_is_rustdesk_is_false`,
`test_is_custom_client_is_true`) so that a future change to `APP_NAME` — e.g. when
merging a new upstream RustDesk release — cannot silently flip them back without a
failing test calling it out.

**Do not "fix" these predicates by making them compare against `"RaatikDesk"` instead
of `"RustDesk"`.** They are meant to answer "is this the stock RustDesk build or a
rebranded one," and RaatikDesk is, by design, the rebranded case. Comparing against the
literal `"RustDesk"` is what makes that answer correct.

This document records every place in the codebase that reads either predicate, what
each site did when the predicate had its old value, what it does now, and why that
change is (or isn't) correct for RaatikDesk. Read it before touching either predicate,
before touching `APP_NAME`, and before merging a new upstream RustDesk release that
might add a new call site.

---

## `is_rustdesk()` — one caller

### `src/lang.rs:225` — `translate()`

```rust
if !crate::is_rustdesk() {
    if s.contains("RustDesk") && !name.starts_with("upgrade_rustdesk_server_pro") && name != "powered_by_me" {
        // ... replace "RustDesk" with get_app_name() in the translated string ...
    }
}
```

- **Stock RustDesk** (`is_rustdesk() == true`): branch never runs; translated UI
  strings keep the literal word "RustDesk".
- **RaatikDesk** (`is_rustdesk() == false`): branch runs; every translated string that
  contains "RustDesk" gets it replaced with the live app name ("RaatikDesk"), except
  the two keys explicitly excluded above.
- **Why this is correct:** this is the actual mechanism that brands the UI at runtime.
  Nothing to fix here — this is the point of the whole exercise.

---

## `is_custom_client()` — every call site

### `src/common.rs:2283` — definition (see above)

### `src/common.rs:2290` — inside `verify_login()` — dead code, no effect

```rust
pub fn verify_login(_raw: &str, _id: &str) -> bool {
    true
    /*
    if is_custom_client() { return true; }
    ... rest of the original signature-verification body ...
    */
}
```

Everything after the unconditional `true` is inside a `/* ... */` block comment and
does not compile. `verify_login()` always returns `true` regardless of this predicate.
Harmless; flagged here only so nobody mistakes it for a live call site.

### `src/common.rs:942` — `check_software_update()`

```rust
pub fn check_software_update() {
    if is_custom_client() { return; }
    // ... otherwise spawns a thread that POSTs to
    // https://api.rustdesk.com/version/latest ...
}
```

- **Stock RustDesk:** ran on startup, contacting `api.rustdesk.com` to check for a new
  version and populate the in-app "update available" notification.
- **RaatikDesk:** early-returns. RaatikDesk never contacts `api.rustdesk.com` through
  this path.
- **This is deliberate and desired.** RAATIK does not want RaatikDesk phoning home to a
  third party (RustDesk's own servers), and does not want RustDesk learning anything
  about RAATIK's customer base (install counts, versions in the field, IPs, etc.). The
  accepted cost: RaatikDesk has **no in-app update notification**. RAATIK distributes
  new versions to customers manually. If that trade-off ever needs to change, it means
  standing up RAATIK's own version-check endpoint and pointing this at it — not
  reverting this predicate.

### `src/ipc.rs:864` — `"hide_cm"` config request handler

```rust
} else if name == "hide_cm" {
    value = if crate::hbbs_http::sync::is_pro() || crate::common::is_custom_client() {
        Some(hbb_common::password_security::hide_cm().to_string())
    } else { None };
```

- **Stock RustDesk:** the "hide the connection-manager window" capability was only
  exposed to builds with an active RustDesk-Server-Pro license (`is_pro()`).
- **RaatikDesk:** also exposed, independent of any RustDesk Pro license.
- `hide_cm()` itself (`libs/hbb_common/src/password_security.rs`) still requires
  `approve-mode == password`, `verification == OnlyUsePermanentPassword`, **and** the
  admin-set `allow-hide-cm` option before it does anything — so this only unlocks a UI
  capability an admin must still explicitly turn on; it doesn't change default security
  posture. RAATIK doesn't use RustDesk's Pro licensing, so being treated as a
  custom/white-label client is the correct classification here.

### `src/flutter_ffi.rs:2475` — FFI passthrough

```rust
pub fn is_custom_client() -> SyncReturn<bool> {
    SyncReturn(crate::common::is_custom_client())
}
```

Exposed to Dart as `bind.isCustomClient()`. Its Dart consumers are listed below.

### `src/flutter_ffi.rs:2861` — `main_get_common()`, `"download-file-{version}"` key

```rust
match (crate::platform::windows::is_msi_installed(), crate::common::is_custom_client()) {
    (Ok(true), false) => ... "rustdesk-{version}-{arch}.msi" ...
    (Ok(true), true) | (Ok(false), _) => ... "rustdesk-{version}-{arch}.exe" ...
    (Err(e), _) => ...
}
```

- **Stock RustDesk:** MSI-installed + non-custom -> resolves a `.msi` update filename;
  otherwise `.exe`.
- **RaatikDesk:** always resolves the `.exe` filename branch.
- In practice this is unreachable: `flutter/lib/common.dart`'s `checkUpdate()` only
  registers the update-check event handler `if (!bind.isCustomClient())`, which is
  false for RaatikDesk, so the update URL that would drive this lookup is never
  populated. Consistent with "no update notification for custom clients"; harmless even
  if it were reached, since `.exe` works regardless of original install method.

### `src/platform/windows.rs:1483` — `remove_meta_toml_cmd()`

```rust
pub fn remove_meta_toml_cmd(is_msi: bool, path: &str) -> String {
    if is_msi && crate::is_custom_client() {
        format!("del /F /Q \"{path}\\meta.toml\"")
    } else { "".to_owned() }
}
```

Called from `update_me()` (the in-place self-update flow) with
`is_msi.unwrap_or(true)`. The `is_msi &&` half of the condition depends on
`is_msi_installed()` actually detecting an MSI install via the registry — it is
independent of branding. RaatikDesk ships the EXE installer
(`rustdesk-<version>-<arch>-install.exe`), so on a normal RaatikDesk deployment this
remains a no-op regardless of `is_custom_client()`. The `is_msi && is_custom_client()`
condition was clearly written upstream for the custom-client-installed-via-MSI
combination; RaatikDesk being classified as a custom client only activates it if
RAATIK ever ships via the WiX MSI project that also lives in this repo (`res/msi`).
**Safe for RAATIK's EXE-only distribution; currently a no-op.**

### `src/platform/windows.rs:2107` — custom-client staging validation

```rust
if is_custom_file_exists && !crate::common::is_custom_client() {
    log::error!("Failed to load custom client from custom.txt.");
    // ... treat this as a load failure and bail ...
}
```

This lives inside the routine that re-stages a runtime `custom.txt` white-label config
file across an in-place update, and is meant to detect a *failed*
`load_custom_client()` call by checking whether `is_custom_client()` is still false
after attempting to load a staged `custom.txt`.

- For a stock binary that only becomes "custom" by successfully loading a runtime
  `custom.txt`, this correctly detected load failures.
- For RaatikDesk, `is_custom_client()` is unconditionally `true` at compile time
  (because `APP_NAME` is baked in via `libs/hbb_common`, not loaded from a runtime
  file), so this specific error branch can never fire — the check is defeated.
- **This does not matter for RaatikDesk in practice.** RAATIK's branding is 100%
  compile-time; no `custom.txt` file exists anywhere in this repo or in the build
  scripts (`build.py`, `Runner.rc`), so the staging directory this function inspects is
  always empty and the function returns success before ever reaching this line.
  **Safe; currently a no-op.** If RAATIK ever adopts the runtime `custom.txt` mechanism
  for some reason, this validation gap would need a real fix (e.g. checking whether the
  staged file was actually consumed, rather than re-checking `is_custom_client()`).

### `src/platform/windows.rs:2240` — `get_custom_icon()`

```rust
fn get_custom_icon(install_dir: &str, exe: &str) -> Option<String> {
    if crate::is_custom_client() {
        // ... look for "data\flutter_assets\assets\icon.ico" next to the exe ...
    }
    None
}
```

Both callers fall back to the exe's own embedded icon when this returns `None`
(`.unwrap_or(exe.to_string())` for the registry DisplayIcon, `.unwrap_or_default()` for
the shortcut, which then just uses the target exe's icon). If a RaatikDesk-branded
`icon.ico` exists next to the installed exe, it's now used for Add/Remove-Programs and
shortcut icons instead of the exe's compiled-in icon; if it doesn't exist, behavior is
identical to before. **Safe either way — this is the intended white-label icon
override, with a behavior-preserving fallback.**

### `src/platform/windows.rs:3490` — `get_reg_msi_key()`

```rust
// Only proceed if it's a custom client and MSI is installed.
if !(crate::common::is_custom_client() && is_msi.unwrap_or(true)) {
    return None;
}
```

The comment already in the source documents that this was written for the
custom-client-plus-MSI combination. Used by `update_me()` to also patch the MSI
product-code registry key during an in-place exe update, so Add/Remove Programs stays
consistent for MSI-installed white-label clients. Same reasoning as
`remove_meta_toml_cmd` above: pre-built white-label support, correctly activated, and a
no-op unless the actual install was detected as MSI. **Safe for RAATIK's EXE-only
distribution.**

### `src/platform/windows.rs:3617` — `update_to()`

```rust
if crate::is_custom_client() {
    handle_custom_client_staging_dir_before_update(&custom_client_staging_dir)?;
} else {
    allow_err!(remove_custom_client_staging_dir(&custom_client_staging_dir));
}
```

RaatikDesk now always takes the "stage `custom.txt` across the update" branch instead
of the "clean up any residual staging dir" branch. Since RAATIK has no `custom.txt`
(see above), `handle_custom_client_staging_dir_before_update` finds nothing to stage and
returns immediately. **Correct branch for a custom client to be in; currently a no-op.**

### `src/updater.rs` — background auto-update (**the one real bug found; fixed**)

```rust
// check_update(), reached from a background thread started unconditionally
// (on Windows, when installed and running as server) by
// rendezvous_mediator.rs:126, and also reachable via the public
// manually_check_update():
fn check_update(manually: bool) -> ResultType<()> {
    if crate::is_custom_client() { return Ok(()); }   // <-- added; see below
    #[cfg(target_os = "windows")]
    let update_msi = crate::platform::is_msi_installed()? && !crate::is_custom_client();
    if !(manually || config::Config::get_bool_option(config::keys::OPTION_ALLOW_AUTO_UPDATE)) {
        return Ok(());
    }
    if do_check_software_update().is_err() { /* ... */ }
    // ... on success, downloads and installs rustdesk-{version}-{arch}.exe/.msi ...
}
```

**This function is the same `do_check_software_update()` — the one that POSTs to
`https://api.rustdesk.com/version/latest` — reached through a second, independent
entry point that was not gated by `is_custom_client()` at all**, unlike
`common::check_software_update()` above. Before the fix, the only gate was the
`allow-auto-update` config option (default off), and:

- The Desktop Settings UI (`flutter/lib/desktop/pages/desktop_setting_page.dart`)
  showed an **"Auto update" checkbox unconditionally** on Windows for installed builds
  — with no `!bind.isCustomClient()` guard — unlike the adjacent "Check for software
  update on startup" checkbox in the same file, which *is* correctly hidden for custom
  clients.

**Failure scenario this made possible:** an admin at a RAATIK customer site opens
Desktop Settings, sees "Auto update" presented as a normal feature, and enables it. The
background thread (started unconditionally whenever RaatikDesk is installed and running
as a server — see `rendezvous_mediator.rs:126`) then calls `do_check_software_update()`
on a daily timer, gets a real answer from `api.rustdesk.com`, downloads
`rustdesk-{version}-{arch}.exe` from RustDesk's own CDN, and silently overwrites the
installed RaatikDesk binary with an **unbranded upstream RustDesk build** — pointed at
RustDesk's own default hbbs/hbbr servers, not RAATIK's. This directly contradicts the
no-phone-home goal recorded above and would silently break the product for any customer
whose admin turned the toggle on.

**Fix applied:**
1. `src/updater.rs` — added `if crate::is_custom_client() { return Ok(()); }` as the
   very first statement of `check_update()`, before any network call or Windows API
   call (`is_msi_installed()`), so RaatikDesk never reaches `do_check_software_update()`
   through this path regardless of the `allow-auto-update` option's value. A test,
   `test_check_update_disabled_for_custom_client` (in the same file), pins this.
2. `flutter/lib/desktop/pages/desktop_setting_page.dart` — added
   `&& !bind.isCustomClient()` to the `showAutoUpdate` condition, matching the existing
   pattern for "Check for software update on startup" in the same file, so the toggle
   is hidden instead of being left visible and now permanently inert.

Both entry points into `check_update()` were checked and are covered by the fix: the
unconditional background thread (`rendezvous_mediator.rs:126` -> `start_auto_update()`)
and the public `manually_check_update()` (currently unused elsewhere in the codebase,
but not gated separately — it funnels through the same guarded `check_update()`).

---

## Flutter/Dart consumers of `bind.isCustomClient()` (informational)

The remaining Dart references — `flutter/lib/common.dart` (default option values:
`approve-mode` defaults to `password-click`, theme defaults to `system`, etc., plus
`checkUpdate()` at line ~4068 which correctly skips registering the update-check
handler for custom clients), `desktop_home_page.dart` (hides the "powered by RustDesk"
attribution unless custom, and hides the "update available, download from
rustdesk.com" help card *for* custom clients), and a few mobile-only pages
(`settings_page.dart`, `connection_page.dart`, `server_page.dart`) — all govern
white-label conveniences that are now correctly activated for RaatikDesk. No issues
found. Mobile is not a shipping platform for RaatikDesk and was only spot-checked.

### `flutter/lib/web/bridge.dart:1610-1613` — WASM/web stub, not a real call site

```dart
bool isCustomClient({dynamic hint}) {
  // is_custom_client() checks if app name is not "RustDesk"
  return mainGetAppNameSync(hint: hint) != "RustDesk";
}
```

This is the web/WASM build's stub re-implementation of the same comparison (the web
target can't call into the native `is_custom_client()` FFI binding, so it duplicates
the logic against the app name it gets over its own bridge). RaatikDesk does not ship a
web build; listed here only for completeness in case a web build is ever added — if so,
this stub needs to keep making the same "not RustDesk" comparison, for the same reason
the Rust predicates do.

### `src/ui.rs`, `src/ui/index.tis` — Sciter UI, not compiled

`src/lib.rs` gates `pub mod ui` on
`#[cfg(not(any(target_os = "android", target_os = "ios", feature = "flutter")))]`.
RaatikDesk is built with the `flutter` feature, so the entire Sciter UI module and
`src/ui/index.tis` (which also reference `is_custom_client`) are not compiled into the
product at all. No effect; not relevant unless the build ever drops the `flutter`
feature.

---

## If you're merging a new upstream RustDesk release

Re-run `grep -rn "is_custom_client\|is_rustdesk" src/ flutter/lib/` and diff the
results against the sites listed above. Any new call site needs the same treatment
this document gives each existing one: figure out what it did when the predicate was
the stock value, what it will do now that RaatikDesk flips it, and whether that's
actually what RAATIK wants — don't assume "custom client" behavior is automatically
safe just because it's white-label plumbing. The `updater.rs` bug above is proof that
it isn't automatic: that gap existed in upstream's own white-label support and would
have shipped unnoticed if this file hadn't been written.
