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
    images.rs    # crate-internal untrusted-image decoding (reencode_png, check_dimensions), not bridged
    api.rs       # pub mod auth; pub mod client; pub mod media; pub mod messages; pub mod profile; pub mod rooms; pub mod sync;
    api/
      client.rs    # shared Client singleton + persistent store config
      auth.rs
      media.rs     # load_media_preview, load_media, save_media (opaque media handles)
      messages.rs  # watch_room_timeline, paginate_backwards, send_text_message (matrix-sdk-ui Timeline)
      profile.rs   # get_profile, set_display_name, set_avatar, remove_avatar
      rooms.rs     # watch_rooms, get_room_name
      sync.rs      # start_sync (background sync loop)
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
#![recursion_limit = "256"]  // see gotchas
pub mod frb_generated;
pub mod api;

// api.rs
pub mod auth;
pub mod client;
pub mod media;
pub mod messages;
pub mod profile;
pub mod rooms;
pub mod sync;
```

### `pub` vs `pub(crate)` — critical rule

Only `pub` items are exposed across the `flutter_rust_bridge` FFI boundary, and bridge-exposed types must be bridge-safe (serializable to the Dart side). **`matrix_sdk::Client` cannot cross the bridge.**

Anything that returns or exposes `matrix_sdk::Client` directly must be `pub(crate)`, never `pub`. Making `get_or_create_client` (or similar) `pub` caused ~15 `SseEncode`/"cannot find type `Client`" compiler errors in the generated `frb_generated.rs` because the codegen tried to make `Client` bridge-safe. If you see errors like that, check for an accidentally-`pub` function returning a non-bridge-safe type first.

### Shared Client singleton pattern

```rust
// api/client.rs (simplified)
static CLIENT_STATE: Mutex<Option<ClientState>> = Mutex::const_new(None); // tokio Mutex
static STORE_CONFIG: OnceLock<StoreConfig> = OnceLock::new();

struct ClientState {
    client: Client,
    tasks: Vec<AbortHandle>,          // background tasks holding a Client clone
    sync_task: Option<AbortHandle>,
}

pub fn set_store(path: String, passphrase: String) -> Result<(), String> { /* sets STORE_CONFIG once */ }
pub async fn reset_client() -> Result<(), String> { /* aborts tasks, drops client, deletes store dir */ }

pub(crate) async fn get_or_create_client(svr_url: &str) -> Result<Client, String> { /* builds under the lock if None */ }
pub(crate) async fn current_client() -> Option<Client> { /* never creates */ }
pub(crate) async fn track_task(task: AbortHandle) { /* aborted on reset */ }
pub(crate) async fn start_sync_task_once(spawn: impl FnOnce() -> AbortHandle) { /* one sync loop per client */ }
```

The client is resettable (`reset_client`, used by `auth::logout` and by `main()` when `restoreSession` fails). Any `spawn`ed task that holds a `Client` clone must be registered with `track_task` (or be the sync task), otherwise it keeps the old client and its store alive after logout. Event handlers registered on the client don't need this, they're dropped with it.

`logout()` revokes the token server-side **best effort** and always resets locally (offline or already-revoked tokens must not leave the user stuck). Dart is responsible for `SessionStorage().clearSession()` and navigating to login.

`Client::clone()` is cheap (it's reference-counted internally), so cloning it out of `CLIENT_STATE` on every call is fine. All `pub` API functions (`login`, `restore_session`, `watch_rooms`, etc.) should go through `get_or_create_client` rather than constructing their own `Client`.

### Persistent store (state + E2EE keys)

The client uses matrix-sdk's SQLite store (the `sqlite` feature is a matrix-sdk default, hence the `libsqlite3-dev` requirement). Without it, E2EE keys live only in memory and encrypted history becomes undecryptable after every restart.

- Location: `<getApplicationSupportDirectory()>/matrix_store` (via `path_provider`).
- Encrypted with a random 32-byte passphrase generated once and kept in `flutter_secure_storage` (`SessionStorage.loadOrCreateStorePassphrase()`).
- `main()` deletes the store when no session is saved: a fresh login gets a new device ID, which an old crypto store would reject.
- `get_or_create_client` deliberately errors if `set_store` wasn't called, rather than silently falling back to an in-memory store.

### Sync loop and streams

- `start_sync` spawns one background `sync_with_result_callback` loop (idempotent per client, via `start_sync_task_once`). Network/server errors are retried after a delay; `M_UNKNOWN_TOKEN` stops the loop.
- Sync state (`Idle`/`Connecting`/`Connected`/`Disconnected`/`SessionExpired`) lives in a global `tokio::sync::watch` in `sync.rs` and reaches Dart via `watch_sync_state`. `AppShell` listens and shows a banner for `Disconnected` ("Offline, reconnecting…") and `SessionExpired` ("Log in again" → logout flow). `reset_client` sets it back to `Idle`, since the aborted loop can't.
- Live data reaches Dart through flutter_rust_bridge `StreamSink`s (Dart sees a `Stream<T>`): `watch_rooms` (re-emits the room list on every `subscribe_to_all_room_updates` tick) and `watch_room_timeline` (a `matrix_sdk_ui::timeline::Timeline` per room; diffs are applied in Rust and the **full** mapped message list is re-sent on every change, so Dart never merges).
- Screens hold the `StreamSubscription` and cancel it in `dispose()`. Rust detects the cancel because `sink.add(...)` starts returning `Err`, and then tears down its side (breaks the loop, dropping the timeline).
- Stream functions must report errors via `sink.add_error(e)` and return `()`, **not** `Result::Err` — the generated Dart wrapper runs the Rust call in an `unawaited` future, so a returned `Err` never reaches the stream listener (the screen would spin forever).
- The room timeline is reachable from `paginate_backwards(room_id, …)` through a `room_id → Weak<Timeline>` map; the watch task owns the `Arc`. Older messages arrive through the stream, not the return value (which is only "reached the start"). `paginate_backwards` repeats (max 5 rounds) until a visible message appears, because pages can consist only of hidden events.
- `RoomScreen` calls `paginateBackwards` once after the first emission (which is only the local cache), then `MessageList` asks for more when scrolled near the top, with a "Load older messages" button as fallback when the content doesn't fill the screen. Date separators are computed in `MessageList` (the Timeline's own `DateDivider` items are skipped: a data-carrying enum on the bridge would need `freezed`). List keys are the timeline's `unique_id`, not event IDs. Sent messages (still `room.send`, not the send queue) arrive back through the timeline.

### Media handles carry decryption keys

Image/file messages come with a `MediaInfo` whose `handle` is a JSON blob (`MediaSource` + thumbnail source + declared size) that Dart passes back to `load_media_preview` / `load_media` / `save_media`. For encrypted media it contains the AES key, so **never log, persist or send it anywhere** on the Dart side. Stateless on purpose (no Rust-side id→source map to clean up).

- Previews: the sender's thumbnail if any, else a server thumbnail (unencrypted only), else the full file for encrypted images. **Always re-encoded in Rust** (`images::reencode_png`, ≤800px PNG, after a header-only pixel check) so Flutter never decodes untrusted bytes at whatever dimensions they claim (decompression bombs). The viewer gets the original bytes, but only after `check_dimensions` (≤32 MP). Don't hand media bytes to `Image.memory` without one of these.
- Byte caps (20 MB preview, 50 MB viewer) are checked against the declared size *and* the actual downloaded size; the SDK itself has no download limit.
- `filename` is sanitized in Rust (`sanitize_filename`: last path component only, no control/bidi-override chars, no leading dots) before it's displayed or suggested in the save dialog. `save_media` uses `create_new`: it refuses to overwrite (the Linux dialog doesn't confirm) and won't follow a symlink.
- Raw downloads are cached in the (encrypted) store, saved files are not.

### Avatar uploads are re-encoded (privacy, don't remove)

`set_avatar` decodes the picked image with the `image` crate (via the shared `images::reencode_png`), applies EXIF orientation, downscales to ≤512px and re-encodes as PNG before uploading. Avatars are public and **not** E2EE (Synapse keeps the original file downloadable), so uploading the raw file would leak EXIF/GPS. This also sniffs the real format from the bytes and rejects oversized dimensions (decompression bombs). Animated GIFs become a still image.

### Error handling across the bridge

Bridge functions return `Result<T, String>` (except `StreamSink` functions, which report errors via `sink.add_error` — see "Sync loop and streams"). Convert SDK errors with `.map_err(|e| e.to_string())?`. Don't try to pass structured/custom error types across the bridge unless there's an actual need for the Dart side to branch on error type.

### Known gotchas (do not re-debug these from scratch)

- **Content hash mismatch** (`Bad state: Content hash on Dart side (...) is different from Rust side (...)`): Dart and Rust sides are out of sync. Fix: `flutter clean && rm -rf rust/target build && flutter pub get && ./rust/check.sh`. This is a full clean rebuild, not a partial fix.
- **`cannot find type 'Client' in this scope'` / `SseEncode` errors in `frb_generated.rs`**: a `pub` function is leaking `matrix_sdk::Client` (or another non-bridge-safe type) across the bridge. Change the offending function to `pub(crate)`, or change its signature to not expose the type.
- **Linker error `unable to find library -lsqlite3'`**: missing system package. Requires `libsqlite3-dev` (plus `libsecret-1-dev`, `libgtk-3-dev` for the Linux desktop target) installed on the build machine.
- **Crate naming**: the Rust crate must be named `rust_lib_r16a_chat_client` — Cargokit expects this naming convention and `integrate` will not find the native library otherwise. (The crate was originally `zmey_core` and had to be renamed.)
- **`integrate` scaffolding conflicts**: `flutter_rust_bridge_codegen integrate` generates a demo `api/` folder that will conflict with hand-written code — delete the generated demo scaffolding before adding real modules, don't try to merge them.
- **Rooms need a sync (or the store) first**: `client.rooms()` / `client.get_room()` are empty until a sync has run or the persistent store has them. `watch_rooms` emits whatever the store has, then re-emits as the sync loop lands. On a very first login the list is briefly empty.
- **Startup ordering** in `main()`: `RustLib.init()` → `setStore()` → `restoreSession()` → `startSync()` → `runApp()`. `setStore` must come before anything that creates the client. The router's auth guard only checks whether a session exists in `flutter_secure_storage` — it does **not** itself restore the session into the Rust `Client`. If `restoreSession()` isn't called, the client ends up unauthenticated (`client.user_id()` is `None`) even though the UI thinks it's logged in. `LoginScreen` also calls `startSync()` after saving the session.
- **`overflow evaluating the requirement ...: Sync/Send`** (E0275) when spawning matrix-sdk futures (e.g. the sync loop): matrix-sdk's futures are deeply nested. Fixed by `#![recursion_limit = "256"]` in `lib.rs` — don't remove it.
- **`StreamSink<T>` isn't `Clone`** unless `T: Clone` — derive `Clone` on bridge structs that are sent through a sink cloned into an event handler (e.g. `MessageSummary`).
- **Plain `cargo clippy` fails on generated code** (`not_unsafe_ptr_arg_deref` in `frb_generated.rs` boilerplate). Lint hand-written code with `cargo clippy -- -A clippy::not_unsafe_ptr_arg_deref`.
- **`u64` crosses the bridge as Dart `BigInt`** — use `i64` (→ `int`) for things like timestamps.
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

- Session validity is only checked by the sync loop: a revoked token surfaces as `SessionExpired` after the first sync, and the user is shown the banner. The router guard itself still only checks that a session exists in local storage. Soft logout (`M_UNKNOWN_TOKEN` with `soft_logout: true`, which would allow re-login keeping the device and keys) is treated like a hard logout.
- Sync 5xx errors are retried inside the SDK for up to 15 minutes before the loop sees them, so a server outage takes that long to show as `Disconnected` (offline/network errors show right away).
- Logout (settings screen → `auth::logout` → `clearSession` → login) deletes the E2EE keys with the store; there's no key backup yet, so old encrypted history is unreadable after logging back in (the confirm dialog says so). If the server-side logout fails, the device lingers in the server's device list. The logout button uses Material's default `colorScheme.error`, not a `ZmeyColors` value.
- Media: receive only, no sending images/files yet. Saving uses `file_selector`'s `getSaveLocation`, which doesn't exist on Android/iOS (desktop only for now). `save_media` holds the whole file in memory (no streaming to disk, no size cap beyond the server's upload limit) and refuses to overwrite existing files (the user has to pick another name). Previews are re-encoded on every load (the store caches the raw download, not the PNG). The file/download icons are Material `Icons`, not the app's SVG set.
- A cancelled `watch_room_timeline` stream is only noticed on the room's next timeline change, so the `Timeline` lingers until then (or until logout aborts it).
- Every timeline change re-maps and re-sends the whole message list across the bridge; fine for now, worth revisiting for rooms with long loaded histories.
- Room screen: text, notices, emotes, "unable to decrypt" and "message deleted" are rendered (`MessageKind`); images show inline (tap → full-screen viewer), files/videos/audio show as a row with a Save button (videos/audio aren't playable); stickers/polls/locations show a "(not supported yet)" placeholder with the fallback text. State events (joins, renames...) are skipped. The UTD placeholder doesn't explain *why* (the SDK's `UtdCause`, e.g. sent before joining, isn't passed through). Edits (applied by the Timeline, "· edited" next to the time) and reactions (chips under the bubble, highlighted when you reacted) are display only: no editing, reacting or un-reacting yet, and no "who reacted" list. No local echo: sending uses `room.send`, not the send queue / `timeline.send`. Room name comes from go_router `extra`, fetched with `get_room_name` on direct navigation.
- `AuthScaffold` (and possibly other screens) still need a proper mobile/desktop `LayoutBuilder` split.
- Settings sub-screens Security, Customize and Storage are routed placeholders with no real content yet. Profile works (display name + avatar) with these gaps: it's fetched once on open (changes from another device only show after reopening); avatar fetch errors silently fall back to the initial letter; "Remove photo" only unsets the avatar URL, the uploaded file stays on the server; the user's own avatar isn't shown anywhere else in the app yet.
- Design-review leftovers (theme/palette decisions pending): light-mode `lightTextSecondary` fails WCAG AA contrast; maroon `primary` makes the cursor/spinners near-invisible in dark mode app-wide (fixed locally in the room screen only); Enter always sends in the composer (no newline on mobile).
- `DetailScaffold` hand-rolls its back button (contradicts the go_router conventions above) and its SVG isn't theme-tinted.

## Build commands

```bash
# Rust side (from rust/)
./build.sh                    # codegen + cargo build, standard dev loop
cargo clippy -- -A clippy::not_unsafe_ptr_arg_deref   # lint (generated code trips that lint)

# Flutter side
flutter_rust_bridge_codegen generate
flutter run -d linux          # or other target
flutter clean && rm -rf rust/target build && flutter pub get && ./rust/check.sh   # full clean rebuild (content hash mismatch fix)
```

System dependencies required on the build machine: `libsqlite3-dev`, `libsecret-1-dev`, `libgtk-3-dev` (Linux desktop target).
