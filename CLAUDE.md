# CLAUDE.md — r16a-chat-client

Read this before making architectural changes, adding dependencies, or "fixing" things that look wrong at first glance — several choices here are intentional.

## Project overview

`r16a-chat-client` is the Flutter + Rust client for **Zmey**, a self-hosted, end-to-end encrypted Matrix-based messaging app. It talks to a Synapse homeserver (deployed separately, repo `r16a-chat`) running at `chat.r16a.cloud` / `zmey.chat`. The motivation is a Swiss-hosted, non-US-jurisdiction alternative to Signal/WhatsApp, partly in response to EU Chat Control legislation.

Sibling repos:
- `r16a-chat` — Kubernetes infra for the Synapse homeserver + Postgres.
- `r16a-chat-web` — Angular marketing/landing site.
- `r16a-chat-client` — this repo. Flutter app with a Rust core (via `flutter_rust_bridge`) that wraps the `matrix-sdk` crate.

## Working style / philosophy

- **Don't add abstraction before there's a second concrete need for it.** No shared libraries, no premature state-management layers, no config systems "for later." Plain duplication across repos/files is preferred until duplication itself becomes the actual problem (e.g. don't extract a shared color package across repos just because two repos have colors).
- **Trust real compiler/runtime errors over assumptions about `matrix-sdk`'s API.** The Rust `matrix-sdk` crate's API has repeatedly not matched assumed/remembered shapes. When something doesn't compile or doesn't behave as expected, check the actual installed crate docs/source rather than guessing harder.
- **Don't silently revert documented intentional decisions** (e.g. the light/dark accent color swap below). If something here looks like a bug, ask or flag it — don't "fix" it back without discussion.
- Keep changes scoped and additive; this is a learning project as much as a product, so avoid large unrequested refactors.

## Architecture: feature-oriented folder structure

```
lib/
  core/          # app-shell-level concerns: router, routes, app shell, detail scaffold
  theme/         # ZmeyColors, AppTheme
  services/      # cross-cutting services (e.g. SessionStorage)
  features/
    auth/
      screens/
      widgets/
    chat/
      screens/
      widgets/
    settings/
      screens/
      widgets/
  src/rust/      # flutter_rust_bridge generated Dart bindings — never hand-edit
rust/
  src/
    lib.rs
    api.rs       # pub mod auth; pub mod rooms; pub mod client;
    api/
      client.rs  # shared Client singleton
      auth.rs
      rooms.rs
```

**Promotion rule**: a widget starts in its feature's `widgets/` folder. It only gets promoted to `core/` once it's genuinely shared across multiple features (e.g. `AppShell`, `DetailScaffold`). Don't pre-emptively put things in `core/` "because they might be reused."

### Smart/dumb widget separation (hard requirement)

This is a hard rule carried over from Angular component conventions:

- **Screens** (in `features/*/screens/`) are "smart" — they own state, call the Rust bridge / services, handle navigation, and own loading/error state.
- **Widgets** (in `features/*/widgets/`) are "dumb" — they take data and callbacks as constructor parameters (`onSubmit`, `isLoading`, `errorMessage`, etc.) and never call the Rust bridge or services directly.

This was violated once (business logic was put directly into `LoginForm` instead of `LoginScreen`) and corrected. See `LoginForm`/`LoginScreen` as the canonical example of the pattern: `LoginForm` is pure presentation; `LoginScreen` owns `_isLoading`/`_errorMessage` state and the full `login()` → `SessionStorage().saveSession()` → `context.go(Routes.chats)` call chain in a try/catch/finally with `if (mounted)` checks.

### Mobile vs desktop layouts

Where a screen needs meaningfully different layouts per breakpoint (e.g. `AuthScaffold`), use `LayoutBuilder` and **separate widgets per breakpoint** (e.g. a mobile-specific widget and a desktop-specific widget), not one widget full of conditional branches.

## Rust ↔ Flutter bridge (flutter_rust_bridge + Cargokit)

### Module layout

Modern style — `api.rs` beside an `api/` folder (not the old `api/mod.rs` style):

```rust
// lib.rs
mod frb_generated;
pub mod api;

// api.rs
pub mod auth;
pub mod client;
pub mod rooms;
```

### `pub` vs `pub(crate)` — critical rule

Only `pub` items are exposed across the `flutter_rust_bridge` FFI boundary, and bridge-exposed types must be bridge-safe (serializable to the Dart side). **`matrix_sdk::Client` cannot cross the bridge.**

Anything that returns or exposes `matrix_sdk::Client` directly must be `pub(crate)`, never `pub`. Making `get_or_create_client` (or similar) `pub` caused ~15 `SseEncode`/"cannot find type `Client`" compiler errors in the generated `frb_generated.rs` because the codegen tried to make `Client` bridge-safe. If you see errors like that, check for an accidentally-`pub` function returning a non-bridge-safe type first.

### Shared Client singleton pattern

```rust
// api/client.rs
use matrix_sdk::Client;
use std::sync::OnceLock;

static CLIENT: OnceLock<Client> = OnceLock::new();

pub(crate) async fn get_or_create_client(homeserver_url: &str) -> Result<Client, String> {
    if let Some(client) = CLIENT.get() {
        return Ok(client.clone());
    }
    let client = Client::builder()
        .homeserver_url(homeserver_url)
        .build()
        .await
        .map_err(|e| e.to_string())?;
    let _ = CLIENT.set(client.clone());
    Ok(client)
}
```

`Client::clone()` is cheap (it's reference-counted internally), so cloning out of the `OnceLock` on every call is fine. All `pub` API functions (`login`, `restore_session`, `get_rooms`, etc.) should go through `get_or_create_client` rather than constructing their own `Client`.

### Error handling across the bridge

Bridge functions return `Result<T, String>`. Convert SDK errors with `.map_err(|e| e.to_string())?`. Don't try to pass structured/custom error types across the bridge unless there's an actual need for the Dart side to branch on error type.

### Known gotchas (do not re-debug these from scratch)

- **Content hash mismatch** (`Bad state: Content hash on Dart side (...) is different from Rust side (...)`): Dart and Rust sides are out of sync. Fix: `flutter clean && rm -rf rust/target build && flutter pub get && ./rust/check.sh`. This is a full clean rebuild, not a partial fix.
- **`cannot find type 'Client' in this scope'` / `SseEncode` errors in `frb_generated.rs`**: a `pub` function is leaking `matrix_sdk::Client` (or another non-bridge-safe type) across the bridge. Change the offending function to `pub(crate)`, or change its signature to not expose the type.
- **Linker error `unable to find library -lsqlite3'`**: missing system package. Requires `libsqlite3-dev` (plus `libsecret-1-dev`, `libgtk-3-dev` for the Linux desktop target) installed on the build machine.
- **Crate naming**: the Rust crate must be named `rust_lib_r16a_chat_client` — Cargokit expects this naming convention and `integrate` will not find the native library otherwise. (The crate was originally `zmey_core` and had to be renamed.)
- **`integrate` scaffolding conflicts**: `flutter_rust_bridge_codegen integrate` generates a demo `api/` folder that will conflict with hand-written code — delete the generated demo scaffolding before adding real modules, don't try to merge them.
- **`get_rooms` requires a sync first**: `client.rooms()` returns empty unless `client.sync_once(SyncSettings::default()).await` has run first. Currently only a one-shot `sync_once` is implemented inside `get_rooms` — there is no persistent background sync loop yet (see "Not yet done" below).
- **Session restore ordering**: the app must call `restoreSession()` into the Rust client during startup *before* `runApp()`. The router's auth guard only checks whether a session exists in `flutter_secure_storage` — it does **not** itself restore the session into the Rust `Client`. If `restoreSession()` isn't called, the client ends up unauthenticated (`client.user_id()` is `None`) even though the UI thinks it's logged in.
- **`WidgetsFlutterBinding.ensureInitialized()`**: must be the very first line of `main()`. Without it, `flutter_secure_storage`'s `read()` throws a `ServicesBinding.instance` error when called before `runApp()`.

### Dev loop

Use `rust/build.sh` for the standard build loop — it wraps `flutter_rust_bridge_codegen generate` and `cargo build` in the correct order. Run it after any change to `rust/src/api*`.

## go_router conventions

- Route path strings live as `static const` fields on a `Routes` class (`lib/core/routes.dart`) — never hardcode raw path strings elsewhere.
- `GoRouter` config (`lib/core/router.dart`) uses a `redirect` function as the auth guard, based on whether `SessionStorage` has a stored session. **Known limitation**: this only checks session *existence* in storage, not validity against the server — see "Not yet done."
- `ShellRoute` wraps `AppShell` around the persistent-nav routes (`/chats`, `/settings`), with nested `GoRoute`s for sub-screens (e.g. settings sections).
- `DetailScaffold` wraps `Scaffold(appBar: AppBar(...))` for drill-down screens and relies on `AppBar`'s automatic back button (which calls `context.pop()` internally) — don't hand-roll back buttons.

## Theming

Two-layer system:
1. `lib/theme/colors.dart` — `ZmeyColors`: raw hex palette, light/dark variants (backgrounds, accent maroon, accent gold, text primary/secondary).
2. `lib/theme/app_theme.dart` — `AppTheme.light` / `AppTheme.dark`: maps `ZmeyColors` into Flutter `ColorScheme` (`primary`, `secondary`, `surface`, `onSurface`, `onSurfaceVariant`).

**Intentional accent swap — don't "fix" this back**: gold is the primary accent in **light** mode, maroon is the primary accent in **dark** mode. This was confirmed deliberately after extensive mockup iteration. If this looks backwards, it isn't — leave it.

Icon theming: SVG icons use `flutter_svg` with `colorFilter`/`BlendMode.srcIn` to tint them per the current theme rather than shipping separate light/dark icon assets.

## State management

Currently manual `StatefulWidget` + `setState` throughout. **Riverpod is the intended direction but has not been introduced yet.** Don't introduce it opportunistically mid-feature — it should be a deliberate, scoped migration when it's actually decided to start.

## Assets

`pubspec.yaml` registers two separate asset folders — both must stay registered if either is used:
```yaml
assets:
  - assets/images/
  - assets/icons/
```

## Known not-yet-done items

These are known gaps, not bugs to silently "complete" without flagging — mention them if touching related code:

- No persistent/continuous Matrix sync loop — only one-shot `sync_once` inside `get_rooms`. Real live messaging needs a background sync loop.
- No real session *validity* check — the router guard only checks that a session exists in local storage, not that it's still valid server-side.
- `AuthScaffold` (and possibly other screens) still need a proper mobile/desktop `LayoutBuilder` split.
- The four settings sub-screens (Profile, Security, Customize, Storage) are routed placeholders with no real content yet.
- `ChatListScreen`'s room-tap handler is a `// navigate into the room, later` placeholder — no room/conversation screen exists yet.
- Any leftover `eprintln!` debug lines in `rust/src/api/rooms.rs` from earlier empty-room-list debugging should be cleaned up when touching that file.

## Build commands

```bash
# Rust side (from rust/)
./build.sh                    # codegen + cargo build, standard dev loop

# Flutter side
flutter_rust_bridge_codegen generate
flutter run -d linux          # or other target
flutter clean && rm -rf rust/target build && flutter pub get && ./rust/check.sh   # full clean rebuild (content hash mismatch fix)
```

System dependencies required on the build machine: `libsqlite3-dev`, `libsecret-1-dev`, `libgtk-3-dev` (Linux desktop target).
