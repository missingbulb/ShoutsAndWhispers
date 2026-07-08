# UI architecture — ports, adapters, and the fake world

The UI must be fully exercisable — every screen, state, and flow — with **no
phone and no server**: location, auth, backend, push, time, and map tiles are
all injected. This is what makes the executable UI requirements in
`dev/requirements/` possible: cases run the *real* UI code against scripted
fakes and render deterministic screenshots.

```
        ┌────────────────────── app/lib ──────────────────────┐
        │  ui (screens, widgets, format)   ← pure Flutter      │
        │        depends ONLY on ↓                             │
        │  ports/ports.dart   ← abstract interfaces + values   │
        │        implemented by either ↓                       │
        │  adapters/   (geolocator, firebase_*, FCM)  ← prod   │
        │  testing/    (scripted fakes, fake tiles)   ← tests  │
        └──────────────────────────────────────────────────────┘
```

Rules:
- **Nothing under `screens/`, `ui/`, or `app.dart` imports** `firebase_*`,
  `cloud_*`, `google_sign_in`, or `geolocator`. The analyzer-visible import
  graph is the boundary; a leaked platform type (a geolocator `Position`, a
  `FirebaseFunctionsException`) is a defect.
- **`main.dart` is the only place adapters are constructed.**
- **The shell is shared.** `lib/app.dart` defines the real root widget
  (`ShoutsAndWhispersShell`) — theme, auth gate, screen routing — used
  *identically* by `main.dart` (with adapters) and by the requirements
  harness (with fakes). Tests never rebuild a parallel app shell; actuals
  come from the shipped one.

## Ports (`lib/ports/ports.dart` — pure Dart, no platform imports)

| port | surface |
|---|---|
| `Clock` | `DateTime now()`. Prod: `SystemClock`. Tests: `FixedClock` (settable, `advance()`). |
| `AuthPort` | `Stream<AppUser?> authStateChanges` (replays latest to new listeners), `Future<void> signInWithGoogle()`, `Future<void> signOut()`. Throws `SignInCanceledException` (user backed out — not an error) or `SignInException(message)`. |
| `LocationPort` | `ValueListenable<GeoPosition?> position` (null until first fix), `ValueListenable<String?> error` (human-readable problem or null), `Future<void> start()`, `void stop()`. |
| `MessagesPort` | `Stream<List<FeedMessage>> feed()` (newest first), `Future<SendResult> send({text, kind, at})`, `Future<void> deleteFeedEntry(messageId)`. Throws `SendException(message)`. |
| `PushPort` | `Future<void> init()`, `void stop()`. Fire-and-forget; the UI never observes push state. |

Value types (also in `ports.dart`): `GeoPosition(lat, lng)`,
`AppUser(uid, displayName, photoUrl)`, `SendResult(messageId,
recipientCount)`. `FeedMessage` (in `models/feed_message.dart`) is
platform-free: `sentAt` is a plain `DateTime`; Firestore `Timestamp`
conversion happens in the messages adapter, not the model.

## Adapters (`lib/adapters/` — the only platform-aware code)

- `firebase_auth_adapter.dart` — google_sign_in v7 flow → Firebase
  credential; maps `GoogleSignInException(canceled)` →
  `SignInCanceledException`, everything else → `SignInException`.
- `geolocator_location_adapter.dart` — permission flow, position stream
  (25 m filter), 2-min heartbeat timer, throttled `presence/{uid}` writes
  (the epoch guard against post-stop re-arming lives here). Presence writing
  is invisible to the UI on purpose — it is a server concern that happens to
  be triggered by movement.
- `firebase_messages_adapter.dart` — `sendMessage` callable + feed snapshot
  stream (`Timestamp` → `DateTime` here) + feed-entry delete; maps
  `FirebaseFunctionsException` → `SendException`.
- `fcm_push_adapter.dart` — notification permission, token upsert into
  presence, token-rotation listener; never throws.

## The fake world (`lib/testing/`)

Shipped inside the package (so `dev/requirements/` can import it) but never
imported by `main.dart`. One file per concern:

- `fakes.dart` — `FakeAuthPort`, `FakeLocationPort`, `FakeMessagesPort`,
  `FakePushPort`, `FixedClock`. Every fake both **scripts** (emit a fix, a
  feed update, an auth change; make the next send fail or hang) and
  **records** (sends, deletes, sign-outs, start/stop calls) so behavior
  cases assert on the recording.
- `fake_tiles.dart` — `FakeTileProvider`: renders deterministic in-memory
  map tiles (soft checkerboard + grid), so map screenshots are byte-stable
  and never touch the network.
- `world.dart` — `FakeWorld`: one object bundling all fakes plus the pinned
  clock, with saga-level verbs (`signIn()`, `fix(lat, lng)`,
  `receive(message)`, `feedNow(list)`) and `buildApp()` returning the real
  `ShoutsAndWhispersShell` wired to the fakes.
- `sample_data.dart` — deterministic sample users/messages, all timestamps
  relative to the reference clock.

**Reference time**: the fake clock is pinned to `2026-06-01 12:00` local
(`referenceNow`). Sample timestamps are offsets from it, so relative-time
labels ("12 min ago") render identically forever.

## What this deliberately does not abstract

`flutter_map` is UI, not platform — the map widget stays a direct
dependency; only its **tile source** is injected (network in prod, fake in
tests). Likewise Material widgets, `intl` formatting, and navigation are the
UI itself, not boundaries.
