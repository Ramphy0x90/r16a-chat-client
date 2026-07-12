# r16a-chat-client

> Status: Early scaffolding, not usable yet

Cross-platform client for [r16a-chat](https://github.com/Ramphy0x90/r16a-chat) — Swiss-made,
self-hosted, end-to-end encrypted messaging built on the Matrix protocol.
actually use: Flutter for the UI, a Rust core for everything security-critical.

---

## What it is

- Single Flutter codebase for mobile (iOS, Android) and desktop (Linux, macOS, Windows)
- All encryption, key management, and session state handled by `matrix-rust-sdk`, via FFI (never in Dart)
- Talks to a self-hosted Synapse homeserver (`chat.r16a.cloud`)

## Stack

| Layer                  | Choice                                              |
| ---------------------- | --------------------------------------------------- |
| UI                     | Flutter                                             |
| Matrix client / crypto | `matrix-rust-sdk` (Rust), via `flutter_rust_bridge` |
| Platforms              | iOS, Android, Linux, macOS, Windows — one codebase  |

## Structure

```
lib/            Dart — UI, screens, widgets
rust/           Rust — matrix-rust-sdk FFI bridge, all key material stays here
android/ ios/ linux/ macos/ windows/    Flutter platform scaffolding
```

`lib/services/matrix_client.dart` is the only file allowed to talk to the Rust bridge directly —
everything else in `lib/` goes through it. That boundary is deliberate: UI code should never be in
a position to touch key material, even by accident.

## License

AGPLv3 — see [LICENSE](./LICENSE). Chosen deliberately: a messaging app whose whole premise is "you
don't have to trust the operator" only works if the code proving that claim is actually verifiable,
including by anyone running a modified or hosted version of it.
